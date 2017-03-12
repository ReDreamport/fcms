_ = require 'lodash'
sizeof = require 'object-sizeof'

util = require '../util'

# 缓存分两类：1、byIdCache：根据 ID 查询单个实体。2、otherCache：其他，包括根据非 ID 查询单个实体。
# 增删改三个操作。增不影响 byIdCache；删和改影响指定 ID 的 byIdCache；
# 但增可能影响所有 otherCache。比如我们查询最新插入一个的实体，新增会导致缓存失效。更新、删除类似。
# TODO 其实还有一个"根据多个ID查询"。增不影响。修改、删除时检查被操作的ID是否在这些ID中，不在就不需要删除缓存。

class EntityServiceCache
    constructor: (@app)->
        @byIdCache = {}
        @otherCache = {}

        @entityCreatedListeners = []
        @entityUpdatedListeners = []
        @entityRemovedListeners = []

        @stats = {query: 0, miss: 0}
        @accessCounter = {}

        @cleanTimer = null

    gWithByIdCache: (entityMeta, cacheId, gQuery)->
        yield from @_gWithCache(entityMeta, @byIdCache, cacheId, gQuery)

    gWithOtherCache: (entityMeta, cacheId, gQuery)->
        yield from @_gWithCache(entityMeta, @otherCache, cacheId, gQuery)

    onEntityCreated: (listener)-> @entityCreatedListeners.push listener

    onEntityUpdated: (listener)-> @entityUpdatedListeners.push listener

    onEntityRemoved: (listener)-> @entityRemovedListeners.push listener

    onUpdatedOrRemoved: (listener)->
        @entityUpdatedListeners.push listener
        @entityRemovedListeners.push listener

    startCleanTimer: ->
        interval = 10 * 60 * 1000 # 10 分钟检查一次
        @cleanTimer = setInterval((=>
            earliest = Date.now() - 6 * 60 * 60 * 1000 # 缓存 6 小时
            for id, item of @byIdCache
                delete @byIdCache[id] if item.createdOn < earliest
            for id, item of @otherCache
                delete @otherCache[id] if item.createdOn < earliest
        ), interval)

    stopCleanTimer: ->
        clearInterval(@cleanTimer) if @cleanTimer?

    gFireEntityCreated: (ctx, entityMeta) ->
        @otherCache[entityMeta.name] = {}

        for l in @entityCreatedListeners
            try
                if util.isGenerator(l)
                    yield from l(ctx, entityMeta)
                else
                    l(ctx, entityMeta)
            catch e
                @app.log.system.error e, "fireEntityCreated"
                throw e

    gFireEntityUpdated: (ctx, entityMeta, ids) ->
        @otherCache[entityMeta.name] = {}

        @_removeByIdCache entityMeta, ids

        for l in @entityUpdatedListeners
            try
                if util.isGenerator(l)
                    yield from l(ctx, entityMeta, ids)
                else
                    l(ctx, entityMeta, ids)
            catch e
                @app.log.system.error e, "onEntityUpdated"
                throw e

    gFireEntityRemoved: (ctx, entityMeta, ids) ->
        @otherCache[entityMeta.name] = {}

        @_removeByIdCache entityMeta, ids

        for l in @entityRemovedListeners
            try
                if util.isGenerator(l)
                    yield from l(ctx, entityMeta, ids)
                else
                    l(ctx, entityMeta, ids)
            catch e
                @app.log.system.error e, "onEntityRemoved"
                throw e

    _incAccessCounter: (entityMeta, cacheId)->
        id = "#{entityMeta.name}/#{cacheId}"
        c = @accessCounter[id]
        if c
            @accessCounter[id] = c + 1
        else
            @accessCounter[id] = 1

    _gWithCache: (entityMeta, cache, cacheId, gQuery)->
        @stats.query++
        @_incAccessCounter(entityMeta.name, cacheId)

        noServiceCache = entityMeta.noServiceCache

        if not noServiceCache
            entityCache = util.setIfNone cache, entityMeta.name, {}
            cacheItem = entityCache[cacheId]
            if cacheItem?
                return _.cloneDeep(cacheItem.value) # 返回拷贝防止污染缓存

        @stats.miss++
        freshValue = yield from gQuery()

        if noServiceCache
            freshValue
        else
            # 这里 Null 值也进入缓存，防止 404 反复触发数据库查询
            entityCache[cacheId] = {value: freshValue, createdOn: Date.now()}
            _.cloneDeep(freshValue) # 返回拷贝防止污染缓存

    _removeByIdCache: (entityMeta, ids)->
        if ids?
            entityByIdCache = @byIdCache[entityMeta.name]
            return unless entityByIdCache?
            for id in ids
                for cacheId of entityByIdCache
                    if cacheId.indexOf(id + "|") == 0 # 缓存ID以实体ID开头
                        delete entityByIdCache[cacheId]
        else
            @byIdCache[entityMeta.name] = {} # 清除全部个体缓存

exports.EntityServiceCache = EntityServiceCache

gClearCache = ->
    @byIdCache = {}
    @otherCache = {}
    yield return

gClearStats = ->
    @stats.query = 0
    @stats.miss = 0
    yield return

gGetStats = ->
    @stats.cacheSizeInBytes = (sizeof(@byIdCache) + sizeof(@otherCache)) / 1024 / 1024
    this.body = @stats
    yield return

gGetTopAccess = ->
    counters = []
    for name, count of accessCounter
        counters.push {name, count}

    this.body = _.sortBy counters, (c)-> -c.count
    yield return




