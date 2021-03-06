Promise = require 'bluebird'
http = require 'http'

log = require '../log'
error = require '../error'
config = require '../config'

extension = require '../extension'

server = null

gCatchError = (next)->
    errorCatcher = @route.info?.errorCatcher
    if errorCatcher
        yield errorCatcher.call(this, next)
    else
        try
            yield next
        catch e
            if e instanceof error.Error401
                @status = 401
                if @route.info?.isPage
                    len = config.urlPrefix.length + 1
                    url = @request.originalUrl.substring(len)
                    @redirect 'sign-in?callback=' + encodeURIComponent(url)
                else
                    @body = e.describe()
            else if e instanceof error.Error403
                @status = 403
                @body = e.describe()
            else if e instanceof error.UserError
                @status = 400
                @body = e.describe()
            else
                @status = 500
                log.system.error e, e.message, 'catch all'

exports.gStart = ->
    koa = require 'koa'
    koaServer = koa()
    koaServer.keys = [config.cookieKey]
    koaServer.proxy = true
    # jade
    koaServer.use(require('./jade').jade.middleware)

    router = require './router'
    router.refresh()

    koaServer.use router.parseRoute

    koaServer.use gCatchError # 匹配路由的过程不需要拦截错误

    ac = require('../handler/AccessController')
    koaServer.use ac.gIdentifyUser
    koaServer.use ac.gControlAccess

    # 控制访问之后再解析正文
    koaBody = require 'koa-body'
    formidableConfig = {uploadDir: config.uploadPath, keepExtensions: true, maxFieldsSize: config.httpBodyMaxFieldsSize}
    koaServer.use(koaBody(multipart: true, formidable: formidableConfig))

    if extension.koaMiddlewareBeforeHandler
        koaServer.use extension.koaMiddlewareBeforeHandler

    koaServer.use router.handleRoute # 开始处理路由

    server = http.createServer(koaServer.callback())

    server.on 'error', (err) ->
        log.system.error err, 'Error on server!'

    enableDestroy = require 'server-destroy'
    enableDestroy(server)

    yield Promise.promisify(server.listen.bind(server))(config.serverPort)

exports.stop = (onWebServerClosed)->
    if server
        server.on 'close', ->
            onWebServerClosed()

        server.destroy()
    else
        onWebServerClosed()