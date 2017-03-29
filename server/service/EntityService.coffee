_ = require 'lodash'

error = require '../error'
util = require '../util'
Meta = require '../Meta'

MongoService = require './EntityServiceMongo'
MysqlService = require './EntityServiceMysql'
EntityCache = require './EntityServiceCache'

Mysql = require '../storage/Mysql'

exports.gCreate = (conn, entityName, instance)->
    entityMeta = Meta.getEntityMeta(entityName)

    throw new error.UserError("CreateEmpty") unless _.size(instance)

    instance._version = 1
    instance._createdOn = new Date()
    instance._modifiedOn = instance._createdOn

    try
        id = if entityMeta.db == Meta.DB.mysql
            yield from MysqlService.gCreate conn, entityMeta, instance
        else if entityMeta.db == Meta.DB.mongo
            yield from MongoService.gCreate entityMeta, instance

        instance._id = id
        return {_id: id}
    finally
        yield from EntityCache.gFireEntityCreated(conn, entityMeta) # 很可能实体还是被某种程度修改，导致缓存失效

exports.gUpdateOneByCriteria = (conn, entityName, criteria, instance)->
    entityMeta = Meta.getEntityMeta(entityName)

    delete instance._id
    delete instance._version
    delete instance._createdBy
    delete instance._createdOn

    return unless _.size(instance)

    instance._modifiedOn = new Date()

    try
        if entityMeta.db == Meta.DB.mysql
            yield from MysqlService.gUpdateOneByCriteria conn, entityMeta, criteria, instance
        else if entityMeta.db == Meta.DB.mongo
            yield from MongoService.gUpdateOneByCriteria entityMeta, criteria, instance
    finally
        yield from EntityCache.gFireEntityUpdated(conn, entityMeta, null) # TODO 清除效率改进

exports.gUpdateManyByCriteria = (conn, entityName, criteria, instance)->
    entityMeta = Meta.getEntityMeta(entityName)

    delete instance._id
    delete instance._version
    delete instance._createdBy
    delete instance._createdOn

    return unless _.size(instance)

    instance._modifiedOn = new Date()

    try
        if entityMeta.db == Meta.DB.mysql
            yield from MysqlService.gUpdateManyByCriteria conn, entityMeta, criteria, instance
        else if entityMeta.db == Meta.DB.mongo
            yield from MongoService.gUpdateManyByCriteria entityMeta, criteria, instance
    finally
        yield from EntityCache.gFireEntityUpdated(conn, entityMeta, null) # TODO 清除效率改进

exports.gRemoveManyByCriteria = (conn, entityName, criteria)->
    entityMeta = Meta.getEntityMeta(entityName)

    try
        if entityMeta.db == Meta.DB.mysql
            yield from MysqlService.gRemoveManyByCriteria conn, entityMeta, criteria
        else if entityMeta.db == Meta.DB.mongo
            yield from MongoService.gRemoveManyByCriteria entityMeta, criteria
        true
    finally
        yield from EntityCache.gFireEntityRemoved(conn, entityMeta, null) # TODO 清除效率改进

exports.gRecoverMany = (conn, entityName, ids)->
    entityMeta = Meta.getEntityMeta(entityName)

    try
        if entityMeta.db == Meta.DB.mysql
            yield from MysqlService.gRecoverMany conn, entityMeta, ids
        else if entityMeta.db == Meta.DB.mongo
            yield from MongoService.gRecoverMany entityMeta, ids
    finally
        yield from EntityCache.gFireEntityCreated(conn, entityMeta)

exports.gFindOneById = (conn, entityName, id, options)->
    entityMeta = Meta.getEntityMeta(entityName)

    cacheId = id + "|" + options?.repo + "|" + options?.includedFields?.join(",")
    criteria = {_id: id}

    yield from EntityCache.gWithByIdCache entityMeta, cacheId, ->
        if entityMeta.db == Meta.DB.mysql
            yield from MysqlService.gFindOneByCriteria conn, entityMeta, criteria, options
        else if entityMeta.db == Meta.DB.mongo
            yield from MongoService.gFindOneByCriteria entityMeta, criteria, options

exports.gFindOneByCriteria = (conn, entityName, criteria, options)->
    entityMeta = Meta.getEntityMeta(entityName)

    cacheId = "OneByCriteria|" + options?.repo + "|" + JSON.stringify(criteria) + "|" + options?.includedFields?.join(",")

    yield from EntityCache.gWithOtherCache entityMeta, cacheId, ->
        if entityMeta.db == Meta.DB.mysql
            yield from MysqlService.gFindOneByCriteria conn, entityMeta, criteria, options
        else if entityMeta.db == Meta.DB.mongo
            yield from MongoService.gFindOneByCriteria entityMeta, criteria, options

exports.gList = (conn, entityName, {repo, criteria, pageNo, pageSize, sort, includedFields, withoutTotal})->
    entityMeta = Meta.getEntityMeta(entityName)

    pageNo = 1 unless pageNo >= 1
    sort = sort || {}
    criteria = criteria || {}

    criteriaString = JSON.stringify(criteria)
    sortString = util.objectToKeyValuePairString(sort)
    includedFieldsString = includedFields?.join(',')

    cacheId = "List|#{repo}|#{pageNo}|#{pageSize}|#{criteriaString}|#{sortString}|#{includedFieldsString}"

    yield from EntityCache.gWithOtherCache entityMeta, cacheId, ->
        query = {repo, entityMeta, criteria, includedFields, sort, pageNo, pageSize, withoutTotal}
        if entityMeta.db == Meta.DB.mysql
            yield from MysqlService.gList conn, query
        else if entityMeta.db == Meta.DB.mongo
            yield from MongoService.gList query

exports.gFindManyByCriteria = (conn, entityName, options)->
    options = options || {}
    options.pageSize = -1
    options.withoutTotal = true

    yield from exports.gList(conn, entityName, options)

exports.gFindManyByIds = (conn, entityName, ids, options)->
    options = options || {}
    options.criteria = {__type: 'relation', field: '_id', operator: 'in', value: ids}
    options.pageSize = -1
    options.withoutTotal = true

    yield from exports.gList(conn, entityName, options)

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