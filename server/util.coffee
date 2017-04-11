_ = require 'lodash'
log = require './log'
Promise = require 'bluebird'
co = require 'co'
xml2js = require("xml2js")
ObjectId = require('mongodb').ObjectId

log = require './log'

jsonfile = require 'jsonfile'
exports.pReadJsonFile = Promise.promisify jsonfile.readFile.bind(jsonfile)
exports.pWriteJsonFile = Promise.promisify jsonfile.writeFile.bind(jsonfile)

exports.objectToKeyValuePairString = (obj)->
    obj && _.join(("#{k}=#{v}" for k,v of obj), "&") || ""

# 结果可能为 null, undefined, NaN
exports.stringToInt = (string, alternative)->
    return string if _.isNumber(string)

    unless string? # 对于 null/undefined 返回 alternative 或原样返回 null/undefined
        return if alternative? then alternative else string

    unless _.isString(string)
        return if alternative? then alternative else undefined

    string = exports.trimString string
    unless string
        return if alternative? then alternative else undefined

    value = parseInt string, 10
    if _.isNaN(value)
        return if alternative? then alternative else value

    value

exports.trimString = (string)->
    return string unless string?
    string.replace(/(^\s*)|(\s*$)/g, "")

# 结果可能为 null, undefined, NaN
exports.stringToFloat = (string, alternative)->
    return string if _.isNumber(string)

    unless string?  # 返回 alternative 或原样返回 null/undefined
        return if alternative? then alternative else string

    unless _.isString(string)
        return if alternative? then alternative else undefined

    string = exports.trimString string
    unless string
        return if alternative? then alternative else undefined

    value = parseFloat string
    if _.isNaN(value)
        return if alternative? then alternative else value

    value

exports.longToDate = (long) ->
    return long if _.isDate(long)
    return long unless long? # 原样返回 null/undefined

    new Date long

exports.dateToLong = (date) ->
    return date unless date?
    date.getTime()

# 将标准 JavaScript 语义的真假值转换为 true 或 false 两个值。
exports.toBoolean = (v)-> Boolean(v)

# 字符串 "false" 转换为 false，"true" 转换为 true，null 原样返回，其余返回 undefined
exports.stringToBoolean = (value)->
    if _.isBoolean(value)
        value
    else if value == "false"
        false
    else if value == "true"
        true
    else if _.isNull(value)
        null
    else
        undefined

exports.arrayToTrueObject = (array)->
    return null unless array
    o = {}
    o[a] = true for a in array
    o

exports.splitString = (string, s)->
    string = _.trim(string)
    return null unless string
    a1 = _.split(string, s)
    a2 = []
    for a in a1
        i = _.trim(a)
        a2.push i if i
    a2

exports.setIfNone = (object, field, alt)->
    v = object[field]
    return v if v?
    object[field] = if _.isFunction(alt) then alt() else alt
    return alt

exports.isGenerator = (fn) ->
    fn?.constructor.name == 'GeneratorFunction'

xmlBuilder = new xml2js.Builder(rootName: 'xml', headless: true)
parseXMLString = Promise.promisify xml2js.parseString.bind(xml2js)

exports.objectToXML = (object)-> xmlBuilder.buildObject(object)

exports.pParseXML = parseXMLString

exports.setTimeout = (timeout, run)-> setTimeout(run, timeout)

exports.setGeneratorTimeout = (timeout, run)->
    run2 = -> co(run).catch (e)-> log.system.error e
    setTimeout(run2, timeout)

exports.setGeneratorInterval = (timeout, run)->
    run2 = -> co(run).catch (e)-> log.system.error e
    setInterval(run2, timeout)

exports.entityListToIdMap = (list)->
    map = {}
    map[i._id] = i for i in list
    map

exports.objectIdsEquals = (a, b)-> a?.toString() == b?.toString()

exports.inObjectIds = (targetId, ids)->
    for id in ids
        return true if id?.toString() == targetId
    false

# 向 EntityHandler list 接口解析后的 criteria 添加条件
exports.addEqualsConditionToListCriteria = (query, field, value)->
    if query.criteria
        criteria = query.criteria
        item = {field, value, operator: '=='}
        if criteria.type == 'relation'
            if criteria.relation == 'and'
                query.criteria.items.push item
            else if criteria.relation == 'or'
                query.criteria = {__type: 'relation', relation: 'and', items: [criteria, item]}
            else
                query.criteria = {__type: 'relation', relation: 'and', items: [criteria, item]}
    else
        query.criteria = {"#{field}": value}

exports.jsObjectToTypedJSON = (jsObject)->
    return jsObject unless jsObject?

    addType = (value)->
        if _.isDate value
            {_type: 'Date', _value: value.getTime()}
        else if value instanceof ObjectId
            {_type: 'ObjectId', _value: value.toString()}
        else if _.isObject(value)
            {_type: 'json', _value: exports.jsObjectToTypedJSON(value)}
        else
            {_type: '', _value: value}

    if _.isArray jsObject
        addType(value) for value in jsObject
    else if _.isObject jsObject
        jsonObject = {}
        jsonObject[key] = addType(value) for key, value of jsObject
        jsonObject
    else
        jsObject

exports.typedJSONToJsObject = (jsonObject)->
    return jsonObject unless jsonObject?

    removeType = (value)->
        switch value._type
            when 'Date' then new Date(value._value)
            when 'ObjectId' then new ObjectId value._value
            when 'json' then exports.typedJSONToJsObject(value._value)
            else
                value._value

    if _.isArray jsonObject
        removeType(value) for value in jsonObject
    else if _.isObject jsonObject
        jsObject = {}
        jsObject[key] = removeType(value) for key, value of jsonObject
        jsObject
    else
        jsonObject
