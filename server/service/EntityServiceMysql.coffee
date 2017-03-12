_ = require 'lodash'

error = require '../error'
mysql = require '../storage/Mysql'
Meta = require '../Meta'

class EntityServiceMysql
    constructor: (@app)->

    gCreate: (conn, entityMeta, instance)->
        return null unless _.size(instance)

        id = Meta.newObjectId().toString()
        instance._id = id

        try
            yield from conn.gInsertOne entityMeta.tableName, instance
            id
        catch e
            throw e unless mysql.isIndexConflictError(e)
            {code, message} = @_toDupKeyError(e, entityMeta)
            throw new error.UniqueConflictError(code, message)

    # 此方法无法实现增加版本号
    gUpdateManyByCriteria: (conn, entityMeta, criteria, instance)->
        return 0 unless _.size(instance)
        try
            yield from conn.gUpdateByCriteria entityMeta.tableName, criteria, instance
        catch e
            throw e unless mysql.isIndexConflictError(e)
            {code, message} = @_toDupKeyError(e, entityMeta)
            throw new error.UniqueConflictError(code, message)

    # instance 要带原版本号
    gUpdateOneByCriteria: (conn, entityMeta, criteria, instance)->
        return 0 unless _.size(instance)
        try
            instance._version = instance._version + 1 if instance._version >= 0

            r = yield from conn.gUpdateByCriteria entityMeta.tableName, criteria, instance
            if r?.changedRows != 1 # 还有一个affectedRows
                throw new error.UserError 'ConcurrentUpdate'
        catch e
            throw e unless mysql.isIndexConflictError(e)
            {code, message} = @_toDupKeyError(e, entityMeta)
            throw new error.UniqueConflictError(code, message)

    gUpdateByIdVersion: (conn, entityMeta, _id, _version, instance)->
        instance._version = _version
        yield from @gUpdateOneByCriteria conn, entityMeta, {__type: 'simple', _id, _version}, instance

    gRemoveMany: (conn, entityMeta, ids)->
        return unless ids?.length
        if entityMeta.removeMode == 'toTrash'
            yield from @_gRemoveManyToTrash(conn, entityMeta, ids)
        else
            yield from @_gRemoveManyCompletely(conn, entityMeta, ids)

    gRecoverMany: (conn, entityMeta, ids)->
        return unless ids?.length
        trashTable = Meta.getCollectionName(entityMeta, "trash")

        list = yield from conn.gListByIds trashTable, ids
        for entity in list
            entity._modifiedOn = new Date()
            entity._version++

        yield from conn.gInsertMany entityMeta.tableName, list # TODO 主键重复？
        yield from conn.gDeleteManyByIds trashTable, ids

    _gRemoveManyToTrash: (conn, entityMeta, ids) ->
        return unless ids?.length
        trashTable = Meta.getCollectionName(entityMeta, "trash")

        list = yield from conn.gListByIds entityMeta.tableName, ids
        for entity in list
            entity._modifiedOn = new Date()
            entity._version++

        if list?.length
            yield from conn.gInsertMany trashTable, list # TODO 主键重复？

        yield from conn.gDeleteManyByIds entityMeta.tableName, ids

    _gRemoveManyCompletely: (conn, entityMeta, ids) ->
        return unless ids?.length
        yield from conn.gDeleteManyByIds entityMeta.tableName, ids

    gFindOneByCriteria: (conn, entityMeta, criteria, {repo, includedFields})->
        table = Meta.getCollectionName entityMeta, repo

        list = yield from conn.gFind {table, criteria, includedFields, pageNo: 1, pageSize: 1}
        list.length && list[0] || null

    gList: (conn, {repo, entityMeta, criteria, includedFields, sort, pageNo, pageSize, withoutTotal})->
        table = Meta.getCollectionName entityMeta, repo

        yield from conn.gFind {
            table, criteria, includedFields, sort,
            pageNo, pageSize, paging: withoutTotal
        }

    _toDupKeyError: (e, entityMeta)->
        matches = e.message.match(/Duplicate entry '(.*)' for key '(.+)'$/)
        if matches
            # value = matches[1]
            key = matches[2]
            specifiedKey = entityMeta.tableName + "_" + key
            indexConfig = _.find entityMeta.mysqlIndexes, (i)-> i.name == specifiedKey
            message = indexConfig?.errorMessage || "值重复：#{key}"
            {code: "DupKey", message, key}
        else
            {code: "DupKey", message: e.message, key: null}

exports.EntityServiceMysql = EntityServiceMysql

