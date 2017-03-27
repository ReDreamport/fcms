mongodb = require 'mongodb'
ObjectId = mongodb.ObjectId
MongoClient = mongodb.MongoClient

log = require '../log'
config = require '../config'

class MongoStore
    constructor: (@name, @url)->

    gDatabase: ->
        return @db if @db

        db = yield MongoClient.connect @url

        db.on 'close', =>
            @db = null
            log.system.info "MongoDB [#{@name}] closed"

        db.on 'error', (e)->
            @db = null
            log.system.error e, "MongoDB [#{@name}] error"

        db.on 'reconnect', ->
            log.system.info "Mongo DB [#{@name}] reconnect"

        @db = db
        return db

    gDispose: ->
        log.system.info "Closing mongodb [#{@name}]..."

        return unless @db
        try
            yield @db.close()
        catch e
            log.system.error e, "dispose mongodb [#{@name}]"

exports.init = ->
    throw new Error 'Mongo config is required now' unless config.mongo?.url
    exports.mongo = new MongoStore 'main', config.mongo.url

exports.gDispose = ->
    yield from exports.mongo.gDispose() if exports.mongo

# 返回值是ObjectId
exports.getInsertedIdObject = (r)->
    return r?.insertedId || null

exports.getUpdateResult = (r)->
    {matchedCount: r.matchedCount, modifiedCount: r.modifiedCount}

exports.isIndexConflictError = (e)-> e.code == 11000

exports.stringToObjectId = (string)->
    return null unless string
    if string instanceof ObjectId
        string
    else
        new ObjectId string

# 可能返回 null / undefined
exports.stringToObjectIdSilently = (string)->
    return string if string instanceof ObjectId

    return string unless string? # 原样返回 null/undefined

    try
        new ObjectId string
    catch
        undefined

exports.stringArrayToObjectIdArraySilently = (strings)->
    return [] unless strings?
    ids = []
    for s in strings
        id = exports.stringToObjectIdSilently s
        ids.push id if id?
    return ids

exports.toMongoCriteria = (criteria)->
    return {} unless criteria

    __type = criteria.__type
    delete criteria.__type

    switch __type
        when 'mongo'
            criteria
        when 'relation'
            mongoCriteria = {}
            toMongoCriteria criteria, mongoCriteria
            mongoCriteria
        else
            criteria

toMongoCriteria = (criteria, mongoCriteria)->
    return unless criteria?

    if criteria.relation == 'or'
        items = []
        for item in criteria.items
            mc = {}
            toMongoCriteria item, mc
            items.push mc if mc
        mongoCriteria['$or'] = items
    else if criteria.relation == 'and'
        for item in criteria.items
            toMongoCriteria item, mongoCriteria
    else if criteria.field
        operator = criteria.operator
        value = criteria.value
        field = criteria.field
        fc = mongoCriteria[field] = mongoCriteria[field] || {}
        switch operator
            when '=='
                mongoCriteria[field] = value
            when '!='
                fc.$ne = value # TODO 对于部分运算符要检查 comparedValue 不为 null/undefined/NaN
            when '>'
                fc.$gt = value
            when '>='
                fc.$gte = value
            when '<'
                fc.$lt = value
            when '<='
                fc.$lte = value
            when 'in'
                fc.$in = value
            when 'nin'
                fc.$nin = value
            when 'start'
                fc.$regex = "^" + value
            when 'end'
                fc.$regex = value + "$"
            when 'contain'
                fc.$regex = value