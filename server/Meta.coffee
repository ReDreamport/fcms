_ = require 'lodash'
crypto = require 'crypto'
ObjectId = require('mongodb').ObjectId
path = require 'path'

util = require './util'

mongo = require './storage/Mongo'

exports.DB = {mongo: 'mongodb', mysql: 'mysql', none: 'none'}

exports.ObjectIdStringLength = 24

# 字段逻辑类型（应用层类型）
FieldDataTypes = ["ObjectId", "String", "Password", "Boolean", "Int", "Float",
    "Date", "Time", "DateTime",
    "Image", "File"
    "Component", "Reference"]

exports.FieldDataTypes = FieldDataTypes

# MongoDB存储类型
MongoPersistTypes = ["ObjectId", "String", "Boolean", "Number", "Date", 'Document']

MySQLPersistTypes = ["varchar", "char", "blob", "text",
    "int", "bit", "tinyint", "bigint", "decimal", "float", "double",
    "datetime", "date", "time", "timestamp"]

AllPersistTypes = MongoPersistTypes.concat(MySQLPersistTypes)
exports.AllPersistTypes = AllPersistTypes

InputTypes = ["Text", "Password", "TextArea", "RichText", "Select", "Check", "Int", "Float", "CheckList"
    "Date", "Time", "DateTime", "File", "Image", "InlineComponent", "PopupComponent", "TabledComponent", "Reference"]

exports.InputTypes = InputTypes

isDateOrTimeType = (fieldType)-> fieldType == "Date" || fieldType == "Time" || fieldType == "DateTime"

class Meta
    constructor: (@app, @metaDir)->
        @cache = null

    getAllMeta: -> @cache

    getEntityMeta: (name)-> @cache.entities[name]

    gLoad: ->
        try
            meta = yield util.pReadJsonFile path.join(@metaDir, "meta.json")
        catch e
            @app.log.system.error e, "fail to load meta"

        meta = meta || {entities: {}, options: {}, version: 0}
        @cache = require('./SystemMeta').patchMeta(meta)
        @app.log.system.info 'meta ready'

    gSaveEntityMeta: (entityName, entityMeta)->
        @cache.entities[entityName] = entityMeta
        yield from @_gPersistMeta()

    gRemoveEntityMeta: (entityName)->
        delete @cache.entities[entityName]
        yield from @_gPersistMeta()

    _gPersistMeta: ->
        try
            meta = yield util.pReadJsonFile path.join(@metaDir, "meta.json")
            yield util.pWriteJsonFile path.join(@metaDir, "meta.json.#{meta.version}"), meta
        catch e
            @app.log.system.error e, "back up old meta"

        @cache.version++
        yield util.pWriteJsonFile path.join(@metaDir, "meta.json"), @cache

        @app.log.system.info "new meta persisted (from #{meta?.version} to #{@cache.version})"

    # 将 HTTP 输入的实体或组件值规范化
    parseEntity: (entityInput, entityMeta)->
        return entityInput unless entityInput?
        return undefined unless _.isObject(entityInput)
        entityValue = {}
        fields = entityMeta.fields
        for fName, fMeta of fields
            fv = @parseFieldValue(entityInput[fName], fMeta)
            entityValue[fName] = fv unless _.isUndefined(fv) || _.isNaN(fv) # undefined / NaN 去掉，null 保留！
        entityValue

    # 将 HTTP 输入的查询条件中的值规范化
    parseListQueryValue: (criteria, entityMeta)->
        # 如果输入的值有问题，可能传递到下面的持久层，如 NaN, undefined, null
        if criteria.relation
            for item in criteria.items
                @parseListQueryValue item, entityMeta
        else if criteria.field
            fieldMeta = entityMeta.fields[criteria.field]
            criteria.value = @parseFieldValue(criteria.value, fieldMeta)

    # 将 HTTP 输入的字段值规范化，value 可以是数组
    parseFieldValue: (value, fieldMeta)->
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
            refEntityMeta = @cache.entities[fieldMeta.refEntity]
            if refEntityMeta
                idMeta = refEntityMeta.fields._id
                @parseFieldValue(value, idMeta)
            else
                @app.log.system.error 'No ref entity' + {refEntity: fieldMeta.refEntity, fieldName: fieldMeta.name}
                null
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
            if _.isArray value
                refEntityMeta = @cache.entities[fieldMeta.refEntity]
                @parseEntity(i, refEntityMeta) for i in value
            else
                @parseEntity value, refEntityMeta
        else if fieldMeta.type == "Password"
            return undefined unless value # 不接受空字符串
            if _.isArray value
                exports.hashPassword(i) for i in value
            else
                exports.hashPassword(value)
        else
            if value then value else null # 空字符串转为 null

    parseId: (id, entityMeta)->
        @parseFieldValue id, entityMeta.fields._id

    parseIds: (ids, entityMeta)->
        return ids unless ids?

        idMeta = entityMeta.fields._id
        list = []
        for id in ids
            i = @parseFieldValue id, idMeta
            list.push i if i?
        list

    outputFieldToHTTP: (fieldValue, fieldMeta)->
        return fieldValue unless fieldValue?

        if isDateOrTimeType(fieldMeta.type)
            if fieldMeta.multiple
                (util.dateToLong(i) for i in fieldValue)
            else
                util.dateToLong(fieldValue)
        else if fieldMeta.type == "Component"
            if fieldMeta.multiple
                refEntityMeta = @cache.entities[fieldMeta.refEntity]
                (@outputEntityToHTTP(i, refEntityMeta) for i in fieldValue)
            else
                @outputEntityToHTTP(fieldValue, refEntityMeta)
        else if fieldMeta.type == "Reference"
            refEntityMeta = @cache.entities[fieldMeta.refEntity]
            unless refEntityMeta
                throw new Error "Cannot find ref entity [" + fieldMeta.refEntity + "] for field " + fieldMeta.name
            idMeta = refEntityMeta.fields._id
            @outputFieldToHTTP(fieldValue, idMeta)
        else if fieldMeta.type == "Password"
            undefined
        else
            fieldValue

    outputEntityToHTTP: (entityValue, entityMeta)->
        return entityValue unless entityValue?

        output = {}

        for fName, fieldMeta of entityMeta.fields
            o = @outputFieldToHTTP entityValue[fName], fieldMeta
            output[fName] = o unless _.isUndefined(o)

        output

exports.Meta = Meta

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

