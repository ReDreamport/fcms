cache = {}

get = (key, alternative) -> cache ? alternative

set = (key, value)-> cache[key] = value

exports.getString = get
exports.setString = set

exports.getCachedString = get
exports.setCachedString = set

exports.getNumber = get
exports.setNumber = set

exports.getBoolean = get
exports.setBoolean = set

exports.getObject = get
exports.setObject = set



