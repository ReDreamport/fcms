config = require '../config'
log = require '../log'

module.exports = if config.cluster
    require('./RedisCache')
else
    require('./MemoryCache')