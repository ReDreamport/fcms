config = require '../config'
log = require '../log'

log.system.info 'cache: ' + config.cache

module.exports = if config.cache == 'redis'
    require('./RedisCache')
else
    require('./MemoryCache')