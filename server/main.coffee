moment = require 'moment'
moment.locale "zh-cn"

co = require 'co'

log = require './log'
config = require './config'

Mongo = require './storage/Mongo'
Mysql = require './storage/Mysql'
Redis = require './storage/Redis'

WebServer = require './web/WebServer'

webStarted = false

gStart = (appConfig, addRouteRules)->
    config[k] = v for k, v of appConfig
    log.config(config)

    console.log "\n\n\n\n\n"
    log.system.info 'Starting FCMS...'

    # 持久层初始化
    Mongo.init()
    Mysql.init()

    if config.cluster
        yield from Redis.gInit()

    # 元数据
    Meta = require './Meta'
    yield from Meta.gLoad()

    # 初始化数据库结构、索引
    MongoIndex = require './storage/MongoIndex'
    yield from MongoIndex.gSyncWithMeta(Mongo.mongo)

    if Mysql.mysql
        RefactorMysqlTable = require './storage/RefactorMysqlTable'
        yield from RefactorMysqlTable.gSyncSchema(exports.mysql)

        MysqlIndex = require './storage/MysqlIndex'
        yield from MysqlIndex.gSyncWithMeta(exports.mysql)

    # 用户
    UserService = require './security/UserService'
    UserService.init()

    yield from require('./init').gInit()

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

    #  TODO yield from require('./service/PromotionService').gPersist()

    if config.cluster
        yield from Redis.gDispose()

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