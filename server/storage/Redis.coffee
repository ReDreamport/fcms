redis = require("redis")
bluebird = require("bluebird")

bluebird.promisifyAll(redis.RedisClient.prototype)
bluebird.promisifyAll(redis.Multi.prototype)

log = require '../log'

exports.init = ->
    client = redis.createClient()
    exports.client = client
    client.on "error", (err) -> log.system.error err, 'init redis'
    client.on "ready", -> log.system.info "Redis ready"
    client.on "connect", -> log.system.info "Redis connect"

exports.dispose = ->
    exports.client?.quit()
