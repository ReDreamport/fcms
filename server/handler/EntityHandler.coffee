_ = require 'lodash'

util = require '../util'
error = require '../error'
Meta = require '../Meta'
mysql = require '../storage/Mysql'

exports.gCreateEntity = ->
    app = @state.app
    entityName = @params.entityName
    entityMeta = app.meta.getEntityMeta(entityName)

    throw new error.UserError('NoSuchEntity') unless entityMeta
    throw new error.UserError('CreateNotAllow') if entityMeta.noCreate

    instance = @request.body
    throw new error.UserError("EmptyOperation") unless instance

    instance = app.meta.parseEntity(instance, entityMeta)

    fieldCount = 0
    for key, value of instance
        if _.isNull(value) then delete instance[key] else fieldCount++
    throw new error.UserError("EmptyOperation") unless fieldCount

    instance._createdBy = @state.user._id

    r = yield from app.entityService.gWithTransaction (conn)->
        yield from app.entityService.gCreate(conn, entityMeta, instance)
    @body = {id: r._id}

exports.gUpdateEntityById = ->
    app = @state.app
    entityName = @params.entityName
    entityMeta = app.meta.getEntityMeta(entityName)

    throw new error.UserError('NoSuchEntity') unless entityMeta
    throw new error.UserError('EditNotAllow') if entityMeta.noEdit

    id = app.meta.parseId(@params.id, entityMeta)
    return @status = 404 unless id?

    instance = @request.body
    _version = instance._version
    instance = app.meta.parseEntity(instance, entityMeta)
    instance._modifiedBy = @state.user._id

    # log.debug 'update ', instance

    yield from app.entityService.gWithTransaction (conn)->
        yield from app.entityService.gUpdateByIdVersion(conn, entityMeta, id, _version, instance)
    @status = 204

exports.gUpdateEntityInBatch = ->
    app = @state.app
    entityName = @params.entityName
    entityMeta = app.meta.getEntityMeta(entityName)

    throw new error.UserError('NoSuchEntity') unless entityMeta
    throw new error.UserError('EditNotAllow') if entityMeta.noEdit

    patch = @request.body
    idVersions = patch.idVersions
    throw new error.UserError('EmptyOperation') unless idVersions.length > 0
    delete patch.idVersions

    patch = app.meta.parseEntity(patch, entityMeta)
    patch._modifiedBy = @state.user._id

    yield from app.entityService.gWithTransaction (conn)->
        for p in idVersions
            id = app.meta.parseId(p.id, entityMeta)
            yield from app.entityService.gUpdateByIdVersion(conn, entityMeta, id, p._version, patch)
    @status = 204

exports.gDeleteEntityInBatch = ->
    app = @state.app
    entityName = @params.entityName
    entityMeta = app.meta.getEntityMeta(entityName)

    throw new error.UserError('NoSuchEntity') unless entityMeta
    throw new error.UserError('DeleteNotAllow') if entityMeta.noDelete

    ids = @query?._ids
    return @status = 400 unless ids

    ids = util.splitString(ids, ",")
    ids = app.meta.parseIds(ids, entityMeta)
    throw new error.UserError('EmptyOperation') unless ids.length > 0

    yield from app.entityService.gWithTransaction (conn)->
        yield from app.entityService.gRemoveMany(conn, entityMeta, ids)
    @status = 204

exports.gRecoverInBatch = ->
    app = @state.app
    entityName = @params.entityName
    entityMeta = app.meta.getEntityMeta(entityName)

    throw new error.UserError('NoSuchEntity') unless entityMeta

    ids = @request.body?.ids
    throw new error.UserError('EmptyOperation') unless ids?.length > 0

    ids = app.meta.parseIds(ids, entityMeta)
    throw new error.UserError('EmptyOperation') unless ids.length > 0

    yield from app.entityService.gWithTransaction (conn)->
        yield from app.entityService.gRecoverMany(conn, entityMeta, ids)
    @status = 204

exports.gFindOneById = ->
    app = @state.app
    entityName = @params.entityName
    entityMeta = app.meta.getEntityMeta(entityName)

    throw new error.UserError('NoSuchEntity') unless entityMeta

    entityId = app.meta.parseId @params.id, entityMeta
    return @status = 404 unless entityId?

    entity = yield from app.entityService.gWithoutTransaction (conn)->
        yield from app.entityService.gFindOneById(conn, entityMeta, entityId, {repo: @query?._repo})

    # TODO 字段过滤

    entity = app.meta.outputEntityToHTTP(entity, entityMeta)

    if entity
        @body = entity
    else
        @status = 404

exports.gList = ->
    app = @state.app
    entityName = @params.entityName
    entityMeta = app.meta.getEntityMeta(entityName)
    throw new error.UserError('NoSuchEntity') unless entityMeta

    query = exports.parseListQuery(entityMeta, @query, app)
    query.entityName = entityName

    r = yield from app.entityService.gWithoutTransaction (conn)->
        yield from app.entityService.gList conn, query

    # TODO 过滤 notInListAPI 的字段
    # TODO 权限字段过滤
    # TODO 密码等字段过滤

    page = (app.meta.outputEntityToHTTP(i, entityMeta) for i in r.page)
    r.page = page

    r.pageNo = query.pageNo
    r.pageSize = query.pageSize

    @body = r

exports.parseListQuery = (entityMeta, query, app)->
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
            app.meta.parseListQueryValue(criteria, entityMeta)

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
    app = @state.app
    req = @request.body
    return @status = 400 unless req

    update = {
        name: req.name, entityName: req.entityName,
        criteria: req.criteria, sortBy: req.sortBy, sortOrder: req.sortOrder
    }

    entityMeta = app.meta.getEntityMeta('F_ListFilters')

    criteria = {name: req.name, entityName: req.entityName}
    includedFields = ['_id', '_version']
    filters = yield from app.entityService.gFindOneByCriteria(null, entityMeta, criteria, {includedFields})
    if filters
        yield from app.entityService.gUpdateByIdVersion(null, entityMeta, filters._id, filters._version, update)
    else
        yield from app.entityService.gCreate(null, filters, update)

    @status = 204

exports.gRemoveFilters = ->
    app = @state.app
    query = @query
    return @status = 400 unless query and query.name and query.entityName

    entityMeta = app.meta.getEntityMeta('F_ListFilters')

    yield from app.entityService.gRemoveManyByCriteria(null, entityMeta, {
        name: query.name, entityName: query.entityName
    })

    @status = 204
