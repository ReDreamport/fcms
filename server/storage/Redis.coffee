redis = require("redis")
bluebird = require("bluebird")
co = require('co')

bluebird.promisifyAll(redis.RedisClient.prototype)
bluebird.promisifyAll(redis.Multi.prototype)

log = require '../log'

subscribers = {}

subscriberClient = null

exports.gInit = ->
    client = redis.createClient()
    exports.client = client
    client.on "error", (err) -> log.system.error err, 'init redis'
    client.on "ready", -> log.system.info "Redis ready"
    client.on "connect", -> log.system.info "Redis connect"

    subscriberClient = redis.createClient()
    subscriberClient.on "subscribe", -> log.system.info "Redis subscribe"

    subscriberClient.on "message", (channel, message) ->
        log.system.info 'ON REDIS MESSAGE', channel, message
        handlers = subscribers[channel]
        if handlers
            for h in handlers
                co -> yield from h(message)

    yield subscriberClient.subscribeAsync 'test', 'MetaChange'

    yield from exports.gPublish 'test', 'hello'

exports.gDispose = ->
    if exports.client
        exports.client.quit()
    if subscriberClient
        yield subscriberClient.unsubscribeAsync 'MetaChange'
        subscriberClient.quit()

exports.subscribe = (channel, handler)->
    subscribers[channel] = subscribers[channel] || []
    subscribers[channel].push handler

exports.gPublish = (channel, message)->
    if exports.client
        yield exports.client.publishAsync channel, message
