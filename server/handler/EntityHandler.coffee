_ = require 'lodash'

util = require '../util'
error = require '../error'
Meta = require '../Meta'
log = require '../log'

EntityService = require '../service/EntityService'

Mysql = require '../storage/Mysql'

EntityInputBridge = require './EntityInputBridge'

exports.gCreateEntity = ->
    entityName = @params.entityName
    entityMeta = Meta.getEntityMeta(entityName)

    throw new error.UserError('NoSuchEntity') unless entityMeta
    throw new error.UserError('CreateNotAllow') if entityMeta.noCreate

    instance = @request.body
    throw new error.UserError("EmptyOperation") unless instance

    instance = Meta.parseEntity(instance, entityMeta)
    # TODO 按权限字段过滤

    fieldCount = 0
    for key, value of instance
        if _.isNull(value) then delete instance[key] else fieldCount++
    throw new error.UserError("EmptyOperation") unless fieldCount

    instance._createdBy = @state.user?._id

    entityMeta = yield from EntityInputBridge.gCreate(entityMeta, instance)

    r = yield from EntityService.gWithTransaction entityMeta, (conn)->
        yield from EntityService.gCreate(conn, entityMeta, instance)
    @body = {id: r._id}

exports.gUpdateEntityById = ->
    entityName = @params.entityName
    entityMeta = Meta.getEntityMeta(entityName)

    throw new error.UserError('NoSuchEntity') unless entityMeta
    throw new error.UserError('EditNotAllow') if entityMeta.noEdit

    id = Meta.parseId(@params.id, entityMeta)
    return @status = 404 unless id?

    instance = @request.body
    _version = instance._version
    instance = Meta.parseEntity(instance, entityMeta)
    # TODO 按权限字段过滤

    instance._modifiedBy = @state.user?._id

    entityMeta = yield from EntityInputBridge.gUpdate(entityMeta, instance, id)

    yield from EntityService.gWithTransaction entityMeta, (conn)->
        yield from EntityService.gUpdateByIdVersion(conn, entityMeta, id, _version, instance)
    @status = 204

exports.gUpdateEntityInBatch = ->
    entityName = @params.entityName
    entityMeta = Meta.getEntityMeta(entityName)

    throw new error.UserError('NoSuchEntity') unless entityMeta
    throw new error.UserError('EditNotAllow') if entityMeta.noEdit

    patch = @request.body
    idVersions = patch.idVersions
    throw new error.UserError('EmptyOperation') unless idVersions.length > 0
    delete patch.idVersions
    iv.id = Meta.parseId(iv.id, entityMeta) for iv in idVersions

    patch = Meta.parseEntity(patch, entityMeta)
    # TODO 按权限字段过滤

    patch._modifiedBy = @state.user?._id

    entityMeta = yield from EntityInputBridge.gUpdateInBatch(entityMeta, patch, idVersions)

    yield from EntityService.gWithTransaction entityMeta, (conn)->
        for p in idVersions
            yield from EntityService.gUpdateByIdVersion(conn, entityMeta, p.id, p._version, patch)
    @status = 204

exports.gDeleteEntityInBatch = ->
    entityName = @params.entityName
    entityMeta = Meta.getEntityMeta(entityName)

    throw new error.UserError('NoSuchEntity') unless entityMeta
    throw new error.UserError('DeleteNotAllow') if entityMeta.noDelete

    ids = @query?._ids
    return @status = 400 unless ids

    ids = util.splitString(ids, ",")
    ids = Meta.parseIds(ids, entityMeta)
    throw new error.UserError('EmptyOperation') unless ids.length > 0

    entityMeta = yield from EntityInputBridge.gDeleteInBatch(entityMeta, ids)

    yield from EntityService.gWithTransaction entityMeta, (conn)->
        yield from EntityService.gRemoveMany(conn, entityMeta, ids)
    @status = 204

exports.gRecoverInBatch = ->
    entityName = @params.entityName
    entityMeta = Meta.getEntityMeta(entityName)

    throw new error.UserError('NoSuchEntity') unless entityMeta

    ids = @request.body?.ids
    throw new error.UserError('EmptyOperation') unless ids?.length > 0

    ids = Meta.parseIds(ids, entityMeta)
    throw new error.UserError('EmptyOperation') unless ids.length > 0

    entityMeta = yield from EntityInputBridge.gRecoverInBatch(entityMeta, ids)

    yield from EntityService.gWithTransaction entityMeta, (conn)->
        yield from EntityService.gRecoverMany(conn, entityMeta, ids)
    @status = 204

exports.gFindOneById = ->
    entityName = @params.entityName
    entityMeta = Meta.getEntityMeta(entityName)

    throw new error.UserError('NoSuchEntity') unless entityMeta

    entityId = Meta.parseId @params.id, entityMeta
    return @status = 404 unless entityId?

    backEntityMeta = Meta.getEntityMeta(entityMeta.backEntity) || entityMeta
    entity = yield from EntityService.gWithoutTransaction backEntityMeta, (conn)->
        yield from EntityService.gFindOneById(conn, backEntityMeta, entityId, {repo: @query?._repo})

    yield from EntityInputBridge.gAfterFindOne(entityMeta, entity, @state.user?._id)

    # TODO 按权限字段过滤

    entity = Meta.outputEntityToHTTP(entity, entityMeta)

    if entity
        @body = entity
    else
        @status = 404

exports.gList = ->
    entityName = @params.entityName
    entityMeta = Meta.getEntityMeta(entityName)
    throw new error.UserError('NoSuchEntity') unless entityMeta

    query = exports.parseListQuery(entityMeta, @query)

    backEntityMeta = Meta.getEntityMeta(entityMeta.backEntity) || entityMeta
    query.entityMeta = backEntityMeta

    yield from EntityInputBridge.gModifyListQuery(entityMeta, query, @state.user?._id)

    r = yield from EntityService.gWithoutTransaction entityMeta, (conn)->
        yield from EntityService.gList conn, query

    # TODO 过滤 notInListAPI 的字段
    # TODO 权限字段过滤
    # TODO 密码等字段过滤

    page = (Meta.outputEntityToHTTP(i, entityMeta) for i in r.page)
    r.page = page

    r.pageNo = query.pageNo
    r.pageSize = query.pageSize

    @body = r

exports.parseListQuery = (entityMeta, query)->
    return {} unless query
    includedFields = util.splitString(query._includedFields, ",")

    digest = query._digest == 'true'
    if digest
        includedFields = if entityMeta.digestFields
            fs = []
            fields = entityMeta.digestFields.split(",")
            for field in fields
                fs = fs.concat field.split('|')
            fs
        else
            ["_id"]

    pageNo = util.stringToInt(query._pageNo, 1)
    pageSize = util.stringToInt(query._pageSize, (digest && -1 || 20))
    pageSize = 200 if pageSize > 200 # TODO 控制量

    # 整理筛选查询条件
    fastFilter = query._filter
    if fastFilter
        orList = []
        orList.push {field: "_id", operator: "==", value: fastFilter}

        for fieldName, fieldMeta of entityMeta.fields
            if fieldMeta.asFastFilter
                orList.push {field: fieldName, operator: "contain", value: fastFilter}

        criteria = {__type: 'relation', relation: "or", items: orList}
    else
        criteria = if query._criteria
            try
                JSON.parse(query._criteria)
            catch e
                throw new error.UserError("BadQueryCriteria")
        else
            criteriaList = []
            for key, value of query
                if key of entityMeta.fields
                    criteriaList.push {field: key, operator: "==", value: value}
            if criteriaList.length
                {__type: 'relation', relation: 'and', items: criteriaList}
            else
                null

        if criteria
            Meta.parseListQueryValue(criteria, entityMeta)
            criteria.__type = 'relation'

    # log.debug 'criteria', criteria

    # 整理排序所用字段
    sort = if query._sort
        try
            JSON.parse(query._sort)
        catch
            null
    else
        sortBy = query._sortBy || '_createdOn'
        sortOrder = if query._sortOrder == 'asc' then 1 else -1
        {"#{sortBy}": sortOrder}

    {repo: query._repo, criteria, includedFields, sort, pageNo, pageSize}

exports.gSaveFilters = ->
    req = @request.body
    return @status = 400 unless req

    update = {
        name: req.name, entityName: req.entityName,
        criteria: req.criteria, sortBy: req.sortBy, sortOrder: req.sortOrder
    }

    entityMeta = Meta.getEntityMeta('F_ListFilters')

    criteria = {name: req.name, entityName: req.entityName}
    includedFields = ['_id', '_version']
    filters = yield from EntityService.gFindOneByCriteria(null, entityMeta, criteria, {includedFields})
    if filters
        yield from EntityService.gUpdateByIdVersion(null, entityMeta, filters._id, filters._version, update)
    else
        yield from EntityService.gCreate(null, filters, update)

    @status = 204

exports.gRemoveFilters = ->
    query = @query
    return @status = 400 unless query and query.name and query.entityName

    entityMeta = Meta.getEntityMeta('F_ListFilters')

    yield from EntityService.gRemoveManyByCriteria(null, entityMeta, {
        name: query.name, entityName: query.entityName
    })

    @status = 204
