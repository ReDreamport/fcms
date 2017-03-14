_ = require 'lodash'

error = require '../error'
Meta = require '../Meta'
log = require '../log'
util = require '../util'

Mongo = require '../storage/Mongo'

exports.gCreate = (entityMeta, instance)->
    # ObjectId 或非 String 的 id 前面设置，这里自动设置 String 类型的 ID
    if entityMeta.fields._id.persistType == 'String' and not instance._id?
        instance._id = Meta.newObjectId().toString()

    db = yield from Mongo.mongo.gDatabase()
    c = db.collection entityMeta.tableName
    try
        res = yield c.insertOne instance
        Mongo.getInsertedIdObject(res)
    catch e
        throw e unless Mongo.isIndexConflictError(e)
        {code, message} = _toDupKeyError(e, entityMeta)
        throw new error.UniqueConflictError(code, message)

exports.gUpdateManyByCriteria = (entityMeta, criteria, instance)->
    update = _objectToMongoUpdate instance
    return 0 unless update

    nativeCriteria = Mongo.toMongoCriteria(criteria)

    db = yield from Mongo.mongo.gDatabase()
    c = db.collection entityMeta.tableName

    try
        res = yield c.updateMany nativeCriteria, update
        r = Mongo.getUpdateResult(res)
        r.modifiedCount
    catch e
        throw e unless Mongo.isIndexConflictError(e)
        {code, message} = _toDupKeyError(e, entityMeta)
        throw new error.UniqueConflictError(code, message)

exports.gUpdateOneByCriteria = (entityMeta, criteria, instance)->
    update = _objectToMongoUpdate instance
    return 0 unless update

    nativeCriteria = Mongo.toMongoCriteria(criteria)

    db = yield from Mongo.mongo.gDatabase()
    c = db.collection entityMeta.tableName

    try
        res = yield c.updateOne nativeCriteria, update
        r = Mongo.getUpdateResult(res)
        if r.modifiedCount != 1
            throw new error.UserError 'ConcurrentUpdate'
    catch e
        throw e unless Mongo.isIndexConflictError(e)
        {code, message} = _toDupKeyError(e, entityMeta)
        throw new error.UniqueConflictError(code, message)

exports.gUpdateByIdVersion = (entityMeta, _id, _version, instance)->
    instance._version = _version
    yield from exports.gUpdateOneByCriteria entityMeta, {__type: 'simple', _id, _version}, instance

exports.gRemoveMany = (entityMeta, ids)->
    if entityMeta.removeMode == 'toTrash'
        yield from _gRemoveManyToTrash(entityMeta, ids)
    else
        yield from _gRemoveManyCompletely(entityMeta, ids)

###
软删除有几种方式：放在单独的表中，放在原来的表中+使用标记字段。
放在单独的表中，在撤销删除后，有id重复的风险：例如删除id为1的实体，其后又产生了id为1的实体，则把删除的实体找回后就主键冲突了
好在目前采用ObjectId的方式不会导致该问题。
放在原表加标记字段的方式，使得所有的查询都要记得查询删除标记为false的实体，并影响索引的构建，麻烦
###
_gRemoveManyToTrash = (entityMeta, ids) ->
    trashTable = Meta.getCollectionName(entityMeta, "trash")

    db = yield from Mongo.mongo.gDatabase()
    formalCollection = db.collection entityMeta.tableName
    trashCollection = db.collection trashTable

    list = yield formalCollection.find({_id: {$in: ids}}).toArray()
    for entity in list
        entity._modifiedOn = new Date()
        entity._version++

    yield trashCollection.insertMany(list)

    yield formalCollection.deleteMany({_id: {$in: ids}})

_gRemoveManyCompletely = (entityMeta, ids) ->
    db = yield from Mongo.mongo.gDatabase()
    c = db.collection entityMeta.tableName
    yield c.deleteMany {_id: {$in: ids}}

exports.gRecoverMany = (entityMeta, ids)->
    trashTable = Meta.getCollectionName(entityMeta, "trash")

    db = yield from Mongo.mongo.gDatabase()
    formalCollection = db.collection entityMeta.tableName
    trashCollection = db.collection trashTable

    list = yield trashCollection.find({_id: {$in: ids}}).toArray()
    for entity in list
        entity._modifiedOn = new Date()
        entity._version++

    try
        yield formalCollection.insertMany(list)
    catch e
        throw e unless Mongo.isIndexConflictError(e)
        {code, message} = _toDupKeyError(e, entityMeta)
        throw new error.UniqueConflictError(code, message)

    yield trashCollection.deleteMany({_id: {$in: ids}})

exports.gFindOneByCriteria = (entityMeta, criteria, o)->
    collectionName = Meta.getCollectionName entityMeta, o?.repo

    nativeCriteria = Mongo.toMongoCriteria(criteria)

    db = yield from Mongo.mongo.gDatabase()
    c = db.collection collectionName
    projection = util.arrayToTrueObject(o?.includedFields) || {}
    yield c.findOne nativeCriteria, projection

# sort 为 mongo 原生格式
exports.gList = ({entityMeta, criteria, sort, repo, includedFields, pageNo, pageSize, withoutTotal})->
    collectionName = Meta.getCollectionName entityMeta, repo

    nativeCriteria = Mongo.toMongoCriteria(criteria)

    includedFields = util.arrayToTrueObject(includedFields) || {}

    db = yield from Mongo.mongo.gDatabase()
    c = db.collection collectionName

    unless withoutTotal
        total = yield c.count(nativeCriteria)

    cursor = c.find(nativeCriteria, includedFields).sort(sort)
    # 判定是否分页
    cursor.skip((pageNo - 1) * pageSize).limit(pageSize) if pageSize > 0

    page = yield cursor.toArray()
    # log.debug 'page', page

    if withoutTotal
        page
    else
        {total, page}

_toDupKeyError = (e, entityMeta)->
    # log.debug 'toDupKeyError, message', e.message
    # E11000 duplicate key error index: fcms.F_User.$F_User_nickname dup key: { : "yyyy" }
    matches = e.message.match(/index:\s(.+)\$(.+) dup key: (.+)/)
    if matches
        indexName = matches[2]
        # value = matches[3]
        log.debug 'toDupKeyError, indexName=' + indexName

        indexConfig = _.find entityMeta.mongoIndexes, (i)-> entityMeta.tableName + "_" + i.name == indexName
        log.system.warn 'No index config for ' + indexName unless indexConfig
        message = indexConfig?.errorMessage || "值重复：#{indexName}"
        {code: "DupKey", message, key: indexName}
    else
        {code: "DupKey", message: e.message, key: null}

_objectToMongoUpdate = (object)->
    return null unless _.size object

    delete object._version
    delete object._id

    set = {}
    unset = {}

    for key, value of object
        if value?
            set[key] = value
        else
            unset[key] = ""

    update = {$inc: {_version: 1}}
    update.$set = set if _.size(set)
    update.$unset = unset if _.size(unset)

    update