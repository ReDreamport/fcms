_ = require 'lodash'
Promise = require 'bluebird'

log = require '../log'

cache = {}
exports.cache = cache

gGet = (keys, alternative) ->
    r = yield Promise.resolve(_.get(cache, keys) ? alternative)
    # log.debug 'get memory cache', keys
    return r

gSet = (keys, value)->
    # log.debug 'set memory cache', keys
    yield Promise.resolve(_.set(cache, keys, value))

exports.gGetString = gGet
exports.gSetString = gSet

exports.gGetCachedString = gGet
exports.gSetCachedString = gSet

exports.gGetObject = gGet
exports.gSetObject = gSet

exports.gUnset = (keys, lastKeys)->
    # log.debug 'unset memory cache', keys, lastKeys
    if lastKeys?.length
        keys = _.clone(keys)
        keysLength = keys.length
        for lastKey in lastKeys
            keys[keysLength] = lastKey
            _.unset cache, keys
    else
        _.unset cache, keys

    yield return

exports.gClearAllCache = ->
    log.system.info("clear all cache / memory")
    cache = {}
    exports.cache = cache
    yield return
