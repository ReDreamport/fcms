co = require 'co'

log = require './log'
applications = require './applications'
WebServer = require './web/WebServer'

config = require './config'

webStarted = false

logInfo = (message)->
    log.system.info '!!! ' + message

onProcessTerm = ->
    console.log "\n\n\n\n\n"
    logInfo "The process terminating..."

    if webStarted
        logInfo "Closing web server firstly..."
        # 先等待服务器关闭，再关闭 Mongo 等
        WebServer.stop(stop)
    else
        stop()

process.on 'SIGINT', onProcessTerm
process.on 'SIGTERM', onProcessTerm

gStop = ->
    logInfo 'Disposing all other resources...'

    yield from applications.gDispose()

    logInfo "ALL CLOSED!"

stop = -> co(gStop).catch (e) -> log.system.error(e, 'stop')

gStart = ->
    console.log "\n\n\n\n\n"

    logInfo 'Starting FCMS...'
    yield from applications.gInit()

    logInfo 'Starting web server...'
    yield from WebServer.gStart(config)
    webStarted = true
    logInfo 'Web server started!'

co(gStart).catch (e) ->
    log.system.error(e, 'Fail to start')
    stop()
