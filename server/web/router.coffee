# 匹配多个路由时，无变量路由直接胜出（至多只能有一个无变量的路由）。
# 有变量的路由，URL不同的部分，最先出现非变量路径的胜出。
# 如 abc/def/:1/ghi 比 abc/def/:1/:2 胜出。

compose = require 'koa-compose'
path = require 'path'

_ = require 'lodash'
log = require '../log'
util = require '../util'

routes = {}

rootMapping = {}
# mapping[method][length][index]
# 如 mapping['get'] 是所有 get 的映射
# mapping['get'][3] 是所有有三段路径的映射，如 /user/:name/detail
# mapping['get'][3][i] 是第 i 段的映射， 0 <= i < 3
mapping = {}

# 将路径切分，去首尾空（去掉首尾的斜线）
splitPath = (aPath)->
    parts = aPath.split("/")
    partsStart = if parts[0] then 0 else 1
    partsEnd = if parts[parts.length - 1] then parts.length else parts.length - 1
    parts.slice(partsStart, partsEnd)

addRouteRules = (method, url, info, handlers...)->
    key = method + url
    for h in handlers
        throw new Error("#{method} #{url}, #{h} is not a generator") unless util.isGenerator h
    handler = if handlers.length == 1 then handlers[0] else compose(handlers)
    route = {method, url, info, handler, indexToVariable: {}}
    routes[key] = route


class RouteRuleRegisters
    constructor: (@appName, @errorCatcher)->
        throw new Error 'appName cannot be empty' unless @appName

    add: (method, url, info, handlers...)->
        url = path.normalize(@appName + "/" + url)
        info = info || {}
        info.errorCatcher = @errorCatcher
        info.appName = @appName
        addRouteRules(method, url, info, handlers...)

    get: (url, info, handlers...)->
        @add 'get', url, info, handlers...
    post: (url, info, handlers...)->
        @add 'post', url, info, handlers...
    put: (url, info, handlers...)->
        @add 'put', url, info, handlers...
    del: (url, info, handlers...)->
        @add 'delete', url, info, handlers...

exports.RouteRuleRegisters = RouteRuleRegisters

exports.refresh = ->
    rootMapping = {}
    mapping = {}

    for key, route of routes
        url = route.url
        method = route.method
        route.indexToVariable = {}

        if url == '' or url == '/'
            rootMapping[method] = url
        else
            parts = splitPath url
            partsLength = parts.length
            mOfMethod = util.setIfNone mapping, method, {}
            mOfLength = util.setIfNone mOfMethod, partsLength, []

            routeWeight = 0
            for part, index in parts
                mOfIndex = util.setIfNone mOfLength, index, {terms: {}, variable: []}

                if part[0] == ':'
                    name = part.slice(1)
                    route.indexToVariable[name] = index
                    mOfIndex.variable.push url
                else
                    mOfTerm = util.setIfNone mOfIndex.terms, part, []
                    mOfTerm.push url
                    routeWeight = routeWeight + (1 << (partsLength - index - 1))
            route.routeWeight = routeWeight

    log.system.info 'routes: ' + _.size(routes)

# 所有匹配 part 单词或变量的路由的 URL
collectRouteUrls = (mOfIndex, part)->
    routeUrlMap = {}
    routeUrls = mOfIndex.terms[part]
    if routeUrls
        for u in routeUrls
            routeUrlMap[u] = true
    routeUrls = mOfIndex.variable
    if routeUrls
        for u in routeUrls
            routeUrlMap[u] = true
    routeUrlMap

match = (method, path, params)->
    method = method.toLowerCase()

    parts = splitPath path
    if path == '' or path == '/'
        routeUrl = rootMapping[method]
        return null unless routeUrl # 不匹配
        routes[method + routeUrl]
    else
        mOfLength = mapping[method]?[parts.length]
        return null unless mOfLength # 不匹配
        possibleRouteUrl = {} # 所有可能匹配的路由的 URL
        for part, index in parts
            mOfIndex = mOfLength[index]
            return null unless mOfIndex # 不匹配
            if index == 0
                # 初始集合
                possibleRouteUrl = collectRouteUrls(mOfIndex, part)
            else
                newPossibleRouteUrl = collectRouteUrls(mOfIndex, part)
                # 取交集
                for u, v of possibleRouteUrl
                    delete possibleRouteUrl[u] unless newPossibleRouteUrl[u]
            return null unless _.size(possibleRouteUrl)
        # 如果有多个匹配，变量出现位置靠后的胜出（没有变量的最胜）
        maxRouteWeight = 0
        finalRoute = null
        for routeUrl, v of possibleRouteUrl
            route = routes[method + routeUrl]
            if route.routeWeight > maxRouteWeight
                finalRoute = route
                maxRouteWeight = route.routeWeight
        for name, index of finalRoute.indexToVariable
            params[name] = parts[index]
        finalRoute

# 解析意图
exports.parseRoute = (next)->
    path = decodeURI(@request.path)
    # log.debug 'parse route, path = ' + path

    params = {}
    route = match(@request.method, path, params)
    if route
        @params = params
        @route = route
        yield next
    else
        log.debug 'fail to match route,', {method: @request.method, path: path}
        @status = 404

# 执行路由的处理器
exports.handleRoute = (next)->
    # 可以 yield 一个 Generator 貌似是 co 库负责的
    # https://github.com/koajs/koa/blob/master/docs/guide.md#middleware-best-practices
    yield @route.handler.call(this, next)

test = ->
    exports.addRouteRules('get', "/", {action: "index"}, (next)-> true)
    exports.addRouteRules('get', "/home", {action: "home"}, (next)-> true)
    exports.addRouteRules('get', "/meta", {action: "meta"}, (next)-> true)
    exports.addRouteRules('post', "/meta", {action: "meta"}, (next)-> true)
    exports.addRouteRules('put', "/meta/:name", {action: "meta"}, (next)-> true)
    exports.addRouteRules('put', "/meta/_blank", {action: "meta"}, (next)-> true)
    exports.addRouteRules('put', "/meta/:name/fields", {action: "meta"}, (next)-> true)
    exports.addRouteRules('get', "/entity/:name/:id", {action: "entity"}, (next)-> true)
    exports.refresh()

    #log.debug JSON.stringify(rootMapping, null, 4)
    log.debug("pathTree", JSON.stringify(mapping, null, 4))

    params = {}
    console.log(match('get', '/entity/User/1', params), params)



















