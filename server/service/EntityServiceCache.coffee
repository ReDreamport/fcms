_ = require 'lodash'
sizeof = require 'object-sizeof'

util = require '../util'
log = require '../log'
Cache = require '../cache/Cache'

# 缓存分两类：1、byIdCache：根据 ID 查询单个实体。2、otherCache：其他，包括根据非 ID 查询单个实体。
# 增删改三个操作。增不影响 byIdCache；删和改影响指定 ID 的 byIdCache；
# 但增可能影响所有 otherCache。比如我们查询最新插入一个的实体，新增会导致缓存失效。更新、删除类似。
# TODO 其实还有一个"根据多个ID查询"。增不影响。修改、删除时检查被操作的ID是否在这些ID中，不在就不需要删除缓存。

entityCreatedListeners = []
entityUpdatedListeners = []
entityRemovedListeners = []

exports.gWithCache = (entityMeta, cacheId, gQuery)->
    noServiceCache = entityMeta.noServiceCache

    if noServiceCache
        yield from gQuery()
    else
        keys = _.concat ['Entity', entityMeta.name], cacheId
        cacheItem = yield from Cache.gGetObject keys
        return _.cloneDeep(cacheItem) if cacheItem? # 返回拷贝防止污染缓存

        freshValue = yield from gQuery()
        return freshValue unless freshValue?

        yield from Cache.gSetObject keys, freshValue
        _.cloneDeep(freshValue) # 返回拷贝防止污染缓存

exports.onEntityCreated = (listener)-> entityCreatedListeners.push listener

exports.onEntityUpdated = (listener)-> entityUpdatedListeners.push listener

exports.onEntityRemoved = (listener)-> entityRemovedListeners.push listener

exports.onUpdatedOrRemoved = (listener)->
    entityUpdatedListeners.push listener
    entityRemovedListeners.push listener

exports.gFireEntityCreated = (ctx, entityMeta) ->
    yield from Cache.gUnset ['Entity', entityMeta.name, 'Other']

    for l in entityCreatedListeners
        try
            if util.isGenerator(l)
                yield from l(ctx, entityMeta)
            else
                l(ctx, entityMeta)
        catch e
            log.system.error e, "fireEntityCreated"
            throw e

exports.gFireEntityUpdated = (ctx, entityMeta, ids) ->
    yield from Cache.gUnset ['Entity', entityMeta.name, 'Other']
    yield from gRemoveOneCacheByIds(entityMeta, ids)

    for l in entityUpdatedListeners
        try
            if util.isGenerator(l)
                yield from l(ctx, entityMeta, ids)
            else
                l(ctx, entityMeta, ids)
        catch e
            log.system.error e, "onEntityUpdated"
            throw e

exports.gFireEntityRemoved = (ctx, entityMeta, ids) ->
    yield from Cache.gUnset ['Entity', entityMeta.name, 'Other']
    yield from gRemoveOneCacheByIds(entityMeta, ids)

    for l in entityRemovedListeners
        try
            if util.isGenerator(l)
                yield from l(ctx, entityMeta, ids)
            else
                l(ctx, entityMeta, ids)
        catch e
            log.system.error e, "onEntityRemoved"
            throw e

gRemoveOneCacheByIds = (entityMeta, ids)->
    if ids
        for id in ids
            yield from Cache.gUnset ['Entity', entityMeta.name, 'Id', id]
    else
        yield from Cache.gUnset ['Entity', entityMeta.name, 'Id']