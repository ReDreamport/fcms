log = require './log'
Meta = require './Meta'

Mongo = require './storage/Mongo'
MongoIndex = require './storage/MongoIndex'

Mysql = require './storage/Mysql'
MysqlIndex = require './storage/MysqlIndex'
RefactorMysqlTable = require './storage/RefactorMysqlTable'

EntityService = require './service/EntityService'

UserService = require './security/UserService'

MailService = require './service/MailService'

SecurityCodeService = require './security/SecurityCodeService'

commonRouterRules = require './web/commonRouterRules'

class Application
    constructor: (@name, @config)->
        #@config.usernameFields
        #@config.sessionExpireAtServer
        #config.metaDir
        #config.mail
        #config.signUpMessage
        #config.data.mongo.main.url
        #config.data.mysql.main
        #config.log.system
        @config.passwordFormat = new RegExp(@config.passwordFormat || '^([a-zA-Z0-9]){8,20}$')

    gInit: ->
        @log = new log.Log(@)

        @meta = new Meta.Meta(@, @config.metaDir)
        yield from @meta.gLoad()

        # 持久层初始化
        mainMongoConfig = @config.data?.mongo?.main
        if mainMongoConfig
            @mongo = new Mongo.MongoStore 'main', mainMongoConfig.url, @

            yield from MongoIndex.gSyncWithMeta(@mongo, @)

        mainMysqlConfig = @config.data?.mysql?.main
        if mainMysqlConfig
            @mysql = new Mysql.MysqlStore mainMysqlConfig, @

            yield from RefactorMysqlTable.gSyncSchema(@mysql, @)
            yield from MysqlIndex.gSyncWithMeta(@mysql, @)

        # 实体服务
        @entityService = new EntityService.EntityService(@)

        # 用户服务
        @userService = new UserService.UserService(@)

        @mailService = new MailService.MailService(@)

        @securityCodeService = new SecurityCodeService.SecurityCodeService(@)

    gDispose: ->
        log.system.info "Disposing application [#{@name}]..."

        #  TODO yield from require('./service/PromotionService').gPersist()
        yield from @entityService.gDispose()

        yield from @mongo.gDispose() if @mongo

        yield from @mysql.gDispose() if @mysql

        log.system.info "Application [#{@name}] disposed"

    getRouteRuleRegisters: (errorCatcher)->
        router = require './web/router'
        new router.RouteRuleRegisters(@name, errorCatcher)

    addCommonRouteRules: (rrr)-> commonRouterRules.addCommonRouteRules(rrr)


exports.Application = Application