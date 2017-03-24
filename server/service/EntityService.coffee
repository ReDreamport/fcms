_ = require 'lodash'

error = require '../error'
util = require '../util'
Meta = require '../Meta'

MongoService = require './EntityServiceMongo'
MysqlService = require './EntityServiceMysql'
EntityCache = require './EntityServiceCache'
Interceptor = require './EntityServiceInterceptor'

Mysql = require '../storage/Mysql'

exports.gCreate = (conn, entityMeta, instance)->
    throw new error.UserError("CreateEmpty") unless _.size(instance)

    instance._version = 1
    instance._createdOn = new Date()
    instance._modifiedOn = instance._createdOn

    gIntercept = Interceptor.getInterceptor entityMeta.name, Interceptor.Actions.Create
    try
        yield from gIntercept conn, instance, ->
            id = if entityMeta.db == Meta.DB.mysql
                yield from MysqlService.gCreate conn, entityMeta, instance
            else if entityMeta.db == Meta.DB.mongo
                yield from MongoService.gCreate entityMeta, instance

            instance._id = id
            return {_id: id}
    finally
        yield from EntityCache.gFireEntityCreated(conn, entityMeta) # 很可能实体还是被某种程度修改，导致缓存失效

exports.gUpdateManyByCriteria = (conn, entityMeta, criteria, instance)->
    delete instance._version
    delete instance._id
    return unless _.size(instance)

    instance._modifiedOn = new Date()

    gIntercept = Interceptor.getInterceptor entityMeta.name, Interceptor.Actions.Update
    try
        yield from gIntercept conn, criteria, instance, ->
            if entityMeta.db == Meta.DB.mysql
                yield from MysqlService.gUpdateManyByCriteria conn, entityMeta, criteria, instance
            else if entityMeta.db == Meta.DB.mongo
                yield from MongoService.gUpdateManyByCriteria entityMeta, criteria, instance
    finally
        yield from EntityCache.gFireEntityUpdated(conn, entityMeta, null) # 清空全部缓存

exports.gUpdateOneByCriteria = (conn, entityMeta, criteria, instance)->
    delete instance._version
    delete instance._id
    return unless _.size(instance)

    instance._modifiedOn = new Date()

    gIntercept = Interceptor.getInterceptor entityMeta.name, Interceptor.Actions.Update
    try
        yield from gIntercept conn, criteria, instance, ->
            if entityMeta.db == Meta.DB.mysql
                yield from MysqlService.gUpdateOneByCriteria conn, entityMeta, criteria, instance
            else if entityMeta.db == Meta.DB.mongo
                yield from MongoService.gUpdateOneByCriteria entityMeta, criteria, instance
    finally
        yield from EntityCache.gFireEntityUpdated(conn, entityMeta, null) # 清空全部缓存 TODO 更新一个，可以先根据条件查ID

exports.gUpdateByIdVersion = (conn, entityMeta, _id, _version, instance)->
    delete instance._version
    delete instance._id
    return unless _.size(instance)

    instance._modifiedOn = new Date()

    gIntercept = Interceptor.getInterceptor entityMeta.name, Interceptor.Actions.Update
    try
        yield from gIntercept conn, {_id, _version}, instance, ->
            if entityMeta.db == Meta.DB.mysql
                yield from MysqlService.gUpdateByIdVersion conn, entityMeta, _id, _version, instance
            else if entityMeta.db == Meta.DB.mongo
                yield from MongoService.gUpdateByIdVersion entityMeta, _id, _version, instance
    finally
        yield from EntityCache.gFireEntityUpdated(conn, entityMeta, [_id])

exports.gRemoveMany = (conn, entityMeta, ids)->
    return unless ids?.length

    gIntercept = Interceptor.getInterceptor entityMeta.name, Interceptor.Actions.Remove
    try
        yield from gIntercept conn, ids, ->
            if entityMeta.db == Meta.DB.mysql
                yield from MysqlService.gRemoveMany conn, entityMeta, ids
            else if entityMeta.db == Meta.DB.mongo
                yield from MongoService.gRemoveMany entityMeta, ids
            true
    finally
        yield from EntityCache.gFireEntityRemoved(conn, entityMeta, ids)

exports.gRemoveManyByCriteria = (conn, entityMeta, criteria)->
    entities = yield from exports.gFindManyByCriteria(conn, {entityMeta, criteria, includedFields: ["_id"]})
    ids = (e._id for e in entities)
    return unless ids.length

    gIntercept = Interceptor.getInterceptor entityMeta.name, Interceptor.Actions.Remove
    try
        yield from gIntercept conn, ids, ->
            if entityMeta.db == Meta.DB.mysql
                yield from MysqlService.gRemoveMany conn, entityMeta, ids
            else if entityMeta.db == Meta.DB.mongo
                yield from MongoService.gRemoveMany entityMeta, ids
            true
    finally
        yield from EntityCache.gFireEntityRemoved(conn, entityMeta, ids)

exports.gRecoverMany = (conn, entityMeta, ids)->
    gIntercept = Interceptor.getInterceptor entityMeta.name, Interceptor.Actions.Recover
    try
        yield from gIntercept conn, ids, ->
            if entityMeta.db == Meta.DB.mysql
                yield from MysqlService.gRecoverMany conn, entityMeta, ids
            else if entityMeta.db == Meta.DB.mongo
                yield from MongoService.gRecoverMany entityMeta, ids
            true
    finally
        yield from EntityCache.gFireEntityCreated(conn, entityMeta)

exports.gFindOneById = (conn, entityMeta, id, options)->
    cacheId = id + "|" + options?.repo + "|" + options?.includedFields?.join(",")
    criteria = {_id: id}

    yield from EntityCache.gWithByIdCache entityMeta, cacheId, ->
        if entityMeta.db == Meta.DB.mysql
            yield from MysqlService.gFindOneByCriteria conn, entityMeta, criteria, options
        else if entityMeta.db == Meta.DB.mongo
            yield from MongoService.gFindOneByCriteria entityMeta, criteria, options

exports.gFindOneByCriteria = (conn, entityMeta, criteria, options)->
    cacheId = "OneByCriteria|" + options?.repo + "|" + JSON.stringify(criteria) + "|" + options?.includedFields?.join(",")

    yield from EntityCache.gWithOtherCache entityMeta, cacheId, ->
        if entityMeta.db == Meta.DB.mysql
            yield from MysqlService.gFindOneByCriteria conn, entityMeta, criteria, options
        else if entityMeta.db == Meta.DB.mongo
            yield from MongoService.gFindOneByCriteria entityMeta, criteria, options

exports.gFindManyByIds = (conn, entityMeta, ids, options)->
    cacheId = "ManyById|" + options?.repo + "|" + _.join(ids, ";") + "|" + options?.includedFields?.join(",")
    criteria = {__type: 'relation', field: '_id', operator: 'in', value: ids}

    yield from EntityCache.gWithOtherCache entityMeta, cacheId, ->
        cr = {repo: options?.repo, entityMeta, criteria, includedFields: options?.includedFields}

        if entityMeta.db == Meta.DB.mysql
            yield from MysqlService.gFindManyByCriteria conn, cr
        else if entityMeta.db == Meta.DB.mongo
            yield from MongoService.gFindManyByCriteria cr

exports.gList = (conn, {entityMeta, repo, criteria, pageNo, pageSize, sort, includedFields, withoutTotal})->
    pageNo = 1 unless pageNo >= 1
    sort = sort || {}
    criteria = criteria || {}

    criteriaString = JSON.stringify(criteria)
    sortString = util.objectToKeyValuePairString(sort)
    includedFieldsString = includedFields?.join(',')

    cacheId = "List|#{repo}|#{pageNo}|#{pageSize}|#{criteriaString}|#{sortString}|#{includedFieldsString}"

    yield from EntityCache.gWithOtherCache entityMeta, cacheId, ->
        cr = {repo, entityMeta, criteria, includedFields, sort, pageNo, pageSize, withoutTotal}
        if entityMeta.db == Meta.DB.mysql
            yield from MysqlService.gList conn, cr
        else if entityMeta.db == Meta.DB.mongo
            yield from MongoService.gList cr

exports.gFindManyByCriteria = (conn, options)->
    options.pageSize = -1
    options.withoutTotal = true
    delete options.sort

    yield from exports.gList(conn, options)

exports.gWithTransaction = (entityMeta, gWork)->
    if entityMeta.db == Meta.DB.mysql
        yield from Mysql.mysql.gWithTransaction (conn)->
            yield from gWork conn
    else
        yield from gWork()

exports.gWithoutTransaction = (entityMeta, gWork)->
    if entityMeta.db == Meta.DB.mysql
        yield from Mysql.mysql.gWithoutTransaction (conn)->
            yield from gWork conn
    else
        yield from gWork()