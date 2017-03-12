_ = require 'lodash'

util = require '../util'
error = require '../error'
Meta = require '../Meta'

mongoService = require './EntityServiceMongo'
mysqlService = require './EntityServiceMysql'
EntityServiceCache = require './EntityServiceCache'
Interceptor = require './EntityServiceInterceptor'

class EntityService
    constructor: (@app)->
        @mongoService = new mongoService.EntityServiceMongo @app
        @mysqlService = new mysqlService.EntityServiceMysql @app

        @interceptor = new Interceptor.EntityServiceInterceptor @app
        @app.entityInterceptor = @interceptor

        @entityCache = new EntityServiceCache.EntityServiceCache @app
        @app.entityCache = @entityCache

        @entityCache.startCleanTimer()

    gDispose: ->
        @entityCache.stopCleanTimer()
        yield return

    gCreate: (conn, entityMeta, instance)->
        throw new error.UserError("CreateEmpty") unless _.size(instance)

        instance._version = 1
        instance._createdOn = new Date()
        instance._modifiedOn = instance._createdOn

        gIntercept = @interceptor.getInterceptor entityMeta.name, Interceptor.Actions.Create
        try
            yield from gIntercept conn, instance, ->
                id = if entityMeta.db == Meta.DB.mysql
                    yield from @mysqlService.gCreate conn, entityMeta, instance
                else if entityMeta.db == Meta.DB.mongo
                    yield from @mongoService.gCreate entityMeta, instance

                instance._id = id
                return {_id: id}
        finally
            yield from @entityCache.gFireEntityCreated(conn, entityMeta) # 很可能实体还是被某种程度修改，导致缓存失效

    gUpdateManyByCriteria: (conn, entityMeta, criteria, instance)->
        delete instance._version
        delete instance._id
        return unless _.size(instance)

        instance._modifiedOn = new Date()

        gIntercept = @interceptor.getInterceptor entityMeta.name, Interceptor.Actions.Update
        try
            yield from gIntercept conn, criteria, instance, ->
                if entityMeta.db == Meta.DB.mysql
                    yield from @mysqlService.gUpdateManyByCriteria conn, entityMeta, criteria, instance
                else if entityMeta.db == Meta.DB.mongo
                    yield from @mongoService.gUpdateManyByCriteria entityMeta, criteria, instance
        finally
            yield from @entityCache.gFireEntityUpdated(conn, entityMeta, null) # 清空全部缓存

    gUpdateOneByCriteria: (conn, entityMeta, criteria, instance)->
        delete instance._version
        delete instance._id
        return unless _.size(instance)

        instance._modifiedOn = new Date()

        gIntercept = @interceptor.getInterceptor entityMeta.name, Interceptor.Actions.Update
        try
            yield from gIntercept conn, criteria, instance, ->
                if entityMeta.db == Meta.DB.mysql
                    yield from @mysqlService.gUpdateOneByCriteria conn, entityMeta, criteria, instance
                else if entityMeta.db == Meta.DB.mongo
                    yield from @mongoService.gUpdateOneByCriteria entityMeta, criteria, instance
        finally
            yield from @entityCache.gFireEntityUpdated(conn, entityMeta, null) # 清空全部缓存 TODO 更新一个，可以先根据条件查ID

    gUpdateByIdVersion: (conn, entityMeta, _id, _version, instance)->
        delete instance._version
        delete instance._id
        return unless _.size(instance)

        instance._modifiedOn = new Date()

        gIntercept = @interceptor.getInterceptor entityMeta.name, Interceptor.Actions.Update
        try
            yield from gIntercept conn, {_id, _version}, instance, ->
                if entityMeta.db == Meta.DB.mysql
                    yield from @mysqlService.gUpdateByIdVersion conn, entityMeta, _id, _version, instance
                else if entityMeta.db == Meta.DB.mongo
                    yield from @mongoService.gUpdateByIdVersion entityMeta, _id, _version, instance
        finally
            yield from @entityCache.gFireEntityUpdated(conn, entityMeta, [_id])


    gRemoveMany: (conn, entityMeta, ids)->
        return unless ids?.length

        gIntercept = @interceptor.getInterceptor entityMeta.name, Interceptor.Actions.Remove
        try
            yield from gIntercept conn, ids, ->
                if entityMeta.db == Meta.DB.mysql
                    yield from mysqlService.gRemoveMany conn, entityMeta, ids
                else if entityMeta.db == Meta.DB.mongo
                    yield from mongoService.gRemoveMany entityMeta, ids
                true
        finally
            yield from @entityCache.gFireEntityRemoved(conn, entityMeta, ids)

    gRemoveManyByCriteria: (conn, entityMeta, criteria)->
        entities = yield from exports.gList(conn, {
            entityMeta, criteria, includedFields: ["_id"], withoutTotal: true
        })
        ids = (e._id for e in entities)
        return unless ids.length

        gIntercept = @interceptor.getInterceptor entityMeta.name, Interceptor.Actions.Remove
        try
            yield from gIntercept conn, ids, ->
                if entityMeta.db == Meta.DB.mysql
                    yield from mysqlService.gRemoveMany conn, entityMeta, ids
                else if entityMeta.db == Meta.DB.mongo
                    yield from mongoService.gRemoveMany entityMeta, ids
                true
        finally
            yield from @entityCache.gFireEntityRemoved(conn, entityMeta, ids)

    gRecoverMany: (conn, entityMeta, ids)->
        gIntercept = @interceptor.getInterceptor entityMeta.name, Interceptor.Actions.Recover
        try
            yield from gIntercept conn, ids, ->
                if entityMeta.db == Meta.DB.mysql
                    yield from mysqlService.gRecoverMany conn, entityMeta, ids
                else if entityMeta.db == Meta.DB.mongo
                    yield from mongoService.gRecoverMany entityMeta, ids
                true
        finally
            yield from @entityCache.gFireEntityCreated(conn, entityMeta)

    gFindOneById: (conn, entityMeta, id, {repo, includedFields})->
        cacheId = id + "|" + repo + "|" + includedFields?.join(",")
        criteria = {_id: id}

        yield from @entityCache.gWithByIdCache entityMeta, cacheId, ->
            if entityMeta.db == Meta.DB.mysql
                yield from mysqlService.gFindOneByCriteria conn, entityMeta, criteria, {repo, includedFields}
            else if entityMeta.db == Meta.DB.mongo
                yield from mongoService.gFindOneByCriteria entityMeta, criteria, {repo, includedFields}

    gFindOneByCriteria: (conn, entityMeta, criteria, {repo, includedFields})->
        cacheId = "OneByCriteria|" + repo + "|" + JSON.stringify(criteria) + "|" + includedFields?.join(",")

        yield from @entityCache.gWithOtherCache entityMeta, cacheId, ->
            if entityMeta.db == Meta.DB.mysql
                yield from mysqlService.gFindOneByCriteria conn, entityMeta, criteria, {repo, includedFields}
            else if entityMeta.db == Meta.DB.mongo
                yield from mongoService.gFindOneByCriteria entityMeta, criteria, {repo, includedFields}

    gFindManyByIds: (conn, entityMeta, ids, {repo, includedFields})->
        cacheId = "ManyById|" + repo + "|" + _.join(ids, ";") + "|" + includedFields?.join(",")
        criteria = {__type: 'relation', field: '_id', operator: 'in', value: ids}

        yield from @entityCache.gWithOtherCache entityMeta, cacheId, ->
            if entityMeta.db == Meta.DB.mysql
                cr = {repo, entityMeta, criteria, includedFields, withoutTotal: true}
                yield from mysqlService.gList conn, cr
            else if entityMeta.db == Meta.DB.mongo
                yield from mongoService.gList cr

    gList: (conn, {entityMeta, repo, criteria, pageNo, pageSize, sort, includedFields, withoutTotal})->
        pageNo = 1 unless pageNo >= 1
        sort = sort || {}

        criteriaString = JSON.stringify(criteria)
        sortString = util.objectToKeyValuePairString(sort)
        includedFieldsString = includedFields?.join(',')

        cacheId = "List|#{repo}|#{pageNo}|#{pageSize}|#{criteriaString}|#{sortString}|#{includedFieldsString}"

        yield from @entityCache.gWithOtherCache entityMeta, cacheId, ->
            cr = {repo, entityMeta, criteria, includedFields, sort, pageNo, pageSize, withoutTotal}
            if entityMeta.db == Meta.DB.mysql
                yield from mysqlService.gList conn, cr
            else if entityMeta.db == Meta.DB.mongo
                yield from mongoService.gList cr

    gWithTransaction: (entityMeta, gWork)->
        if entityMeta.db == Meta.DB.mysql
            yield from @app.mysql.gWithTransaction (conn)->
                yield from gWork conn
        else
            yield from gWork()

    gWithoutTransaction: (entityMeta, gWork)->
        if entityMeta.db == Meta.DB.mysql
            yield from @app.mysql.gWithoutTransaction (conn)->
                yield from gWork conn
        else
            yield from gWork()

exports.EntityService = EntityService
