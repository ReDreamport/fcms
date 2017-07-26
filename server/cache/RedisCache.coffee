Redis = require '../storage/Redis'
_ = require 'lodash'

log = require '../log'
util = require '../util'

keySeparator = ":"

gGet = (keys, alternative) ->
    key = keys.join(keySeparator)
    yield Redis.client.getAsync(key) ? alternative

gSet = (keys, value)->
    key = keys.join(keySeparator)
    yield Redis.client.setAsync key, value

exports.gGetString = gGet
exports.gSetString = gSet

exports.gGetCachedString = gGet
exports.gSetCachedString = gSet

exports.gGetObject = (keys, alternative) ->
    str = yield from gGet keys, alternative
    json = str && JSON.parse str
    util.typedJSONToJsObject json

exports.gSetObject = (keys, value)->
    value = util.jsObjectToTypedJSON(value)
    str = value && JSON.stringify(value)
    yield from gSet(keys, str)

exports.gUnset = (keys, lastKeys)->
    if lastKeys?.length
        keys = _.clone keys
        keysLength = keys.length

        keys2 = []
        for lastKey in lastKeys
            keys[keysLength] = lastKey
            keys2.push keys.join(keySeparator)
        keys = keys2
    else
        key = keys.join(keySeparator) + "*"
        keys = yield Redis.client.keysAsync key

    log.debug 'unset redis keys', keys

    yield Redis.client.delAsync keys if keys.length

exports.gClearAllCache = ->
    keys = yield Redis.client.keysAsync "*"
    yield Redis.client.delAsync keys if keys.length

test = ->
    log.config({})
    Redis.init()
    require('co')(->
        yield from exports.gSetObject ['aaa'], {a: 1, time: new Date(), aaa: [4, 5]}
        v = yield from exports.gGetObject ['aaa']
        console.log v

        yield from exports.gUnset(["a"], [1, 2, 3, 4])
    ).catch (e)-> log.system.error e, 'test'