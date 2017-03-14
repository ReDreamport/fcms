_ = require 'lodash'
crypto = require 'crypto'
ObjectId = require('mongodb').ObjectId
path = require 'path'

util = require './util'
log = require './log'

mongo = require './storage/Mongo'

exports.DB = {mongo: 'mongodb', mysql: 'mysql', none: 'none'}

exports.ObjectIdStringLength = 24

# 字段逻辑类型（应用层类型）
exports.FieldDataTypes = ["ObjectId", "String", "Password", "Boolean", "Int", "Float",
    "Date", "Time", "DateTime",
    "Image", "File"
    "Component", "Reference", "Object"]

# MongoDB存储类型
MongoPersistTypes = ["ObjectId", "String", "Boolean", "Number", "Date", 'Document']

MySQLPersistTypes = ["varchar", "char", "blob", "text",
    "int", "bit", "tinyint", "bigint", "decimal", "float", "double",
    "datetime", "date", "time", "timestamp"]

exports.AllPersistTypes = MongoPersistTypes.concat(MySQLPersistTypes)

exports.InputTypes = ["Text", "Password", "TextArea", "RichText", "Select", "Check", "Int", "Float", "CheckList"
    "Date", "Time", "DateTime", "File", "Image", "InlineComponent", "PopupComponent", "TabledComponent", "Reference"]

exports.actions = {}

isDateOrTimeType = (fieldType)-> fieldType == "Date" || fieldType == "Time" || fieldType == "DateTime"

metaCache = null
enhancedViewMetaCache = {}
metaDir = null

exports.getMetaCache = -> metaCache

# 获取实体或视图（合并后的视图）
exports.getEntityMeta = (name)->
    metaCache.entities[name] || enhancedViewMetaCache[name]

# 获取纯实体
exports.getEntities = -> metaCache.entities

# 前端使用的元数据
exports.getMetaForFront = -> {entities: metaCache.entities, views: enhancedViewMetaCache}

exports.gLoad = (theMetaDir)->
    metaDir = theMetaDir
    try
        meta = yield util.pReadJsonFile path.join(metaDir, "meta.json")
    catch e
        log.system.error e, "fail to load meta"

    meta = meta || {entities: {}, views: {}, version: 0}
    meta.entities = meta.entities || {}
    meta.views = meta.views || {}

    metaCache = require('./SystemMeta').patchMeta(meta)

    enhanceViews()

    log.system.info 'Meta loaded'

exports.gSaveEntityMeta = (entityName, entityMeta)->
    metaCache.entities[entityName] = entityMeta
    enhanceViews()
    yield from _gPersistMeta()

exports.gRemoveEntityMeta = (entityName)->
    delete metaCache.entities[entityName]
    yield from _gPersistMeta()

exports.gSaveViewMeta = (viewName, viewMeta)->
    metaCache.views[viewName] = viewMeta
    enhanceViews()
    yield from _gPersistMeta()

exports.gRemoveViewMeta = (viewName)->
    delete metaCache.views[viewName]
    delete enhancedViewMetaCache[viewName]
    yield from _gPersistMeta()

_gPersistMeta = ->
    try
        oldMeta = yield util.pReadJsonFile path.join(metaDir, "meta.json")
        yield util.pWriteJsonFile path.join(metaDir, "meta.json.#{oldMeta.version}"), oldMeta
    catch e
        log.system.error e, "back up old meta"

    metaCache.version++
    yield util.pWriteJsonFile path.join(metaDir, "meta.json"), metaCache

# 补全视图的元数据
enhanceViews = ->
    enhancedViewMetaCache = {}

    for viewName, viewMeta of metaCache.views
        backEntityMeta = metaCache.entities[viewMeta.backEntity]
        enhancedViewMeta = _.clone(backEntityMeta)
        for k, v of viewMeta
            enhancedViewMeta[k] = v if v? # 覆盖

        enhancedViewMeta.fields = {}
        for fieldName, fieldMeta of viewMeta.fields
            backFieldMeta = _.find backEntityMeta.fields, (f)-> f.name == fieldName
            enhancedFieldMeta = _.clone(backFieldMeta)
            for k,v of fieldMeta
                enhancedFieldMeta[k] = v if v? # 覆盖

            enhancedViewMeta.fields[fieldName] = enhancedFieldMeta

        enhancedViewMetaCache[viewName] = enhancedViewMeta

# 将 HTTP 输入的实体或组件值规范化
# 过滤掉元数据中没有的字段
exports.parseEntity = (entityInput, entityMeta)->
    return entityInput unless entityInput?
    return undefined unless _.isObject(entityInput)
    entityValue = {}
    fields = entityMeta.fields
    for fName, fMeta of fields
        fv = exports.parseFieldValue(entityInput[fName], fMeta)
        entityValue[fName] = fv unless _.isUndefined(fv) || _.isNaN(fv) # undefined / NaN 去掉，null 保留！
    entityValue

# 将 HTTP 输入的查询条件中的值规范化
exports.parseListQueryValue = (criteria, entityMeta)->
    # 如果输入的值有问题，可能传递到下面的持久层，如 NaN, undefined, null
    if criteria.relation
        for item in criteria.items
            exports.parseListQueryValue item, entityMeta
    else if criteria.field
        fieldMeta = entityMeta.fields[criteria.field]
        criteria.value = exports.parseFieldValue(criteria.value, fieldMeta)

# 将 HTTP 输入的字段值规范化，value 可以是数组
exports.parseFieldValue = (value, fieldMeta)->
    return undefined unless fieldMeta # TODO 异常处理
    # null / undefined 语义不同
    return value unless value? # null/undefined 原样返回

    # for 循环放在 if 内为提高效率
    if isDateOrTimeType(fieldMeta.type)
        if _.isArray value
            util.longToDate(i) for i in value
        else
            util.longToDate value
    else if fieldMeta.type == "ObjectId"
        if _.isArray value
            mongo.stringToObjectIdSilently(i) for i in value # null 值不去
        else
            mongo.stringToObjectIdSilently value
    else if fieldMeta.type == "Reference"
        refEntityMeta = exports.getEntityMeta fieldMeta.refEntity
        throw new Error "No ref entity [#{fieldMeta.refEntity}]. Field #{fieldMeta.name}" unless refEntityMeta?
        idMeta = refEntityMeta.fields._id
        exports.parseFieldValue(value, idMeta)
    else if fieldMeta.type == "Boolean"
        if _.isArray value
            util.stringToBoolean(i) for i in value
        else
            util.stringToBoolean(value)
    else if fieldMeta.type == "Int"
        if _.isArray value
            util.stringToInt(i) for i in value
        else
            util.stringToInt(value)
    else if fieldMeta.type == "Float"
        if _.isArray value
            util.stringToFloat(i) for i in value
        else
            util.stringToFloat(value)
    else if fieldMeta.type == "Component"
        refEntityMeta = exports.getEntityMeta fieldMeta.refEntity
        throw new Error "No ref entity [#{fieldMeta.refEntity}]. Field #{fieldMeta.name}" unless refEntityMeta?

        if _.isArray value
            exports.parseEntity(i, refEntityMeta) for i in value
        else
            exports.parseEntity value, refEntityMeta
    else if fieldMeta.type == "Password"
        return undefined unless value # 不接受空字符串
        if _.isArray value
            exports.hashPassword(i) for i in value
        else
            exports.hashPassword(value)
    else
        if value then value else null # 空字符串转为 null

exports.parseId = (id, entityMeta)->
    exports.parseFieldValue id, entityMeta.fields._id

exports.parseIds = (ids, entityMeta)->
    return ids unless ids?

    idMeta = entityMeta.fields._id
    list = []
    for id in ids
        i = exports.parseFieldValue id, idMeta
        list.push i if i?
    list

exports.outputFieldToHTTP = (fieldValue, fieldMeta)->
    return fieldValue unless fieldValue?

    if isDateOrTimeType(fieldMeta.type)
        if fieldMeta.multiple
            (util.dateToLong(i) for i in fieldValue)
        else
            util.dateToLong(fieldValue)
    else if fieldMeta.type == "Component"
        refEntityMeta = exports.getEntityMeta fieldMeta.refEntity
        throw new Error "No ref entity [#{fieldMeta.refEntity}]. Field #{fieldMeta.name}" unless refEntityMeta?

        if fieldMeta.multiple
            (exports.outputEntityToHTTP(i, refEntityMeta) for i in fieldValue)
        else
            exports.outputEntityToHTTP(fieldValue, refEntityMeta)
    else if fieldMeta.type == "Reference"
        fieldValue # TODO 原样输出即可
    else if fieldMeta.type == "Password"
        undefined
    else
        fieldValue

exports.outputEntityToHTTP = (entityValue, entityMeta)->
    return entityValue unless entityValue?

    output = {}

    for fName, fieldMeta of entityMeta.fields
        o = exports.outputFieldToHTTP entityValue[fName], fieldMeta
        output[fName] = o unless _.isUndefined(o)

    output

exports.hashPassword = (password)->
    return password unless password?
    crypto.createHash('md5').update(password + password).digest('hex')

exports.getCollectionName = (entityMeta, repo) ->
    switch repo
        when 'trash' then entityMeta.tableName + "_trash"
        else
            entityMeta.tableName

exports.newObjectId = -> new ObjectId()

exports.imagePathsToImageObjects = (paths, thumbnailFilled) ->
    return paths unless paths?.length

    for path in paths
        o = {path: path}
        o.thumbnail = path if thumbnailFilled
        o

