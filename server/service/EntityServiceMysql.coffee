_ = require 'lodash'

error = require '../error'
Meta = require '../Meta'

Mysql = require '../storage/Mysql'

exports.gCreate = (conn, entityMeta, instance)->
    return null unless _.size(instance)

    id = Meta.newObjectId().toString()
    instance._id = id

    try
        yield from conn.gInsertOne entityMeta.tableName, instance
        id
    catch e
        throw e unless Mysql.isIndexConflictError(e)
        {code, message} = _toDupKeyError(e, entityMeta)
        throw new error.UniqueConflictError(code, message)

# 此方法无法实现增加版本号
exports.gUpdateManyByCriteria = (conn, entityMeta, criteria, instance)->
    return 0 unless _.size(instance)
    try
        yield from conn.gUpdateByCriteria entityMeta.tableName, criteria, instance
    catch e
        throw e unless Mysql.isIndexConflictError(e)
        {code, message} = _toDupKeyError(e, entityMeta)
        throw new error.UniqueConflictError(code, message)

# instance 要带原版本号
exports.gUpdateOneByCriteria = (conn, entityMeta, criteria, instance)->
    return 0 unless _.size(instance)
    try
        instance._version = instance._version + 1 if instance._version >= 0

        r = yield from conn.gUpdateByCriteria entityMeta.tableName, criteria, instance
        if r?.changedRows != 1 # 还有一个affectedRows
            throw new error.UserError 'ConcurrentUpdate'
    catch e
        throw e unless Mysql.isIndexConflictError(e)
        {code, message} = _toDupKeyError(e, entityMeta)
        throw new error.UniqueConflictError(code, message)

exports.gRemoveManyByCriteria = (conn, entityMeta, criteria)->
    return unless ids?.length
    if entityMeta.removeMode == 'toTrash'
        yield from _gRemoveManyToTrash(conn, entityMeta, criteria)
    else
        yield from _gRemoveManyCompletely(conn, entityMeta, criteria)

exports.gRecoverMany = (conn, entityMeta, ids)->
    return unless ids?.length
    trashTable = Meta.getCollectionName(entityMeta, "trash")

    list = yield from conn.gListByIds trashTable, ids
    for entity in list
        entity._modifiedOn = new Date()
        entity._version++

    yield from conn.gInsertMany entityMeta.tableName, list # TODO 主键重复？
    yield from conn.gDeleteManyByIds trashTable, ids

_gRemoveManyToTrash = (conn, entityMeta, criteria) ->
    return unless ids?.length
    trashTable = Meta.getCollectionName(entityMeta, "trash")

    list = yield from conn.gFind {table: entityMeta.tableName, criteria, pageSize: -1, paging: false}

    for entity in list
        entity._modifiedOn = new Date()
        entity._version++

    if list?.length
        yield from conn.gInsertMany trashTable, list # TODO 主键重复？

    yield from conn.gDeleteManyByCriteria entityMeta.tableName, criteria

_gRemoveManyCompletely = (conn, entityMeta, criteria) ->
    return unless ids?.length
    yield from conn.gDeleteManyByCriteria entityMeta.tableName, criteria

exports.gFindOneByCriteria = (conn, entityMeta, criteria, o)->
    table = Meta.getCollectionName entityMeta, o?.repo

    list = yield from conn.gFind {table, criteria, includedFields: o?.includedFields, pageNo: 1, pageSize: 1}
    list.length && list[0] || null

exports.gList = (conn, {repo, entityMeta, criteria, includedFields, sort, pageNo, pageSize, withoutTotal})->
    table = Meta.getCollectionName entityMeta, repo

    yield from conn.gFind {table, criteria, includedFields, sort, pageNo, pageSize, paging: withoutTotal}

_toDupKeyError = (e, entityMeta)->
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


