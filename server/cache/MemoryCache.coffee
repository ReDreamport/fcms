_ = require 'lodash'
Promise = require 'bluebird'

cache = {}

gGet = (keys, alternative) -> yield Promise.resolve(_.get(cache, keys) ? alternative)

gSet = (keys, value)-> yield Promise.resolve(_.set(cache, keys, value))

exports.gGetString = gGet
exports.gSetString = gSet

exports.gGetCachedString = gGet
exports.gSetCachedString = gSet

exports.gGetObject = gGet
exports.gSetObject = gSet

exports.gUnset = (keys, lastKeys)->
    if lastKeys?.length
        keys = _.clone(keys)
        keysLength = keys.length
        for lastKey in lastKeys
            keys[keysLength] = lastKey
            _.unset cache, keys
    else
        _.unset cache, keys


