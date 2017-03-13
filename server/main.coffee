moment = require 'moment'
moment.locale "zh-cn"

co = require 'co'

log = require './log'
config = require './config'

Mongo = require './storage/Mongo'
Mysql = require './storage/Mysql'

EntityServiceCache = require './service/EntityServiceCache'

WebServer = require './web/WebServer'

webStarted = false

gStart = (appConfig, addRouteRules)->
    config[k] = v for k, v of appConfig
    log.config(config)

    console.log "\n\n\n\n\n"
    log.system.info 'Starting FCMS...'

    # 元数据
    Meta = require './Meta'
    yield from Meta.gLoad(config.metaDir)

    # 持久层初始化
    yield from Mongo.gInit()

    yield from Mysql.gInit()

    EntityServiceCache.startCleanTimer()

    # 用户
    UserService = require './security/UserService'
    yield from UserService.gInit()

    # 路由表
    router = require './web/router'
    rrr = new router.RouteRuleRegisters(config.urlPrefix, config.errorCatcher)
    commonRouterRules = require './web/commonRouterRules'
    commonRouterRules.addCommonRouteRules(rrr)
    addRouteRules?(rrr)

    log.system.info 'Starting the web server...'
    yield from WebServer.gStart()
    webStarted = true
    log.system.info 'Web server started!'

gStop = ->
    log.system.info 'Disposing all other resources...'

    EntityServiceCache.stopCleanTimer()

    #  TODO yield from require('./service/PromotionService').gPersist()

    yield from Mongo.gDispose()
    yield from Mysql.gDispose()

    log.system.info "ALL CLOSED!\n\n"

exports.start = (appConfig, addRouteRules)->
    co(-> yield from gStart(appConfig, addRouteRules)).catch (e) ->
        log.system.error(e, 'Fail to start')
        exports.stop()

stop = ->
    co(gStop).catch (e) -> log.system.error(e, 'stop')

onProcessTerm = ->
    console.log "\n\n\n\n\n"
    log.system.info "The process terminating..."

    if webStarted
        log.system.info "Closing web server firstly..."
        # 先等待服务器关闭，再关闭 Mongo 等
        WebServer.stop(stop)
    else
        stop()

process.on 'SIGINT', onProcessTerm
process.on 'SIGTERM', onProcessTerm