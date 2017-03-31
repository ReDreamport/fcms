_ = require 'lodash'

util = require '../util'
error = require '../error'
Meta = require '../Meta'
log = require '../log'

EntityService = require '../service/EntityService'
Interceptor = require './EntityInterceptor'

Mysql = require '../storage/Mysql'

exports.gCreateEntity = ->
    entityName = @params.entityName
    entityMeta = Meta.getEntityMeta(entityName)

    throw new error.UserError('NoSuchEntity') unless entityMeta
    throw new error.UserError('CreateNotAllow') if entityMeta.noCreate

    instance = @request.body
    throw new error.UserError("EmptyOperation") unless instance

    instance = Meta.parseEntity(instance, entityMeta)
    exports.removeNoCreateFields entityMeta, @state.user, instance

    fieldCount = 0
    for key, value of instance
        if _.isNull(value) then delete instance[key] else fieldCount++
    throw new error.UserError("EmptyOperation") unless fieldCount

    instance._createdBy = @state.user?._id

    gIntercept = Interceptor.getInterceptor entityName, Interceptor.Actions.Create
    operator = @state.user

    r = yield from EntityService.gWithTransaction entityMeta, (conn)->
        yield from gIntercept conn, instance, operator, ->
            yield from EntityService.gCreate(conn, entityName, instance)

    @body = {id: r._id}

exports.gUpdateEntityById = ->
    entityName = @params.entityName
    entityMeta = Meta.getEntityMeta(entityName)

    throw new error.UserError('NoSuchEntity') unless entityMeta
    throw new error.UserError('EditNotAllow') if entityMeta.noEdit

    _id = Meta.parseId(@params.id, entityMeta)
    return @status = 404 unless _id?

    instance = @request.body

    criteria = {_id, _version: instance._version}

    instance = Meta.parseEntity(instance, entityMeta)
    exports.removeNoEditFields entityMeta, @state.user, instance

    instance._modifiedBy = @state.user?._id

    gIntercept = Interceptor.getInterceptor entityName, Interceptor.Actions.Update
    operator = @state.user

    yield from EntityService.gWithTransaction entityMeta, (conn)->
        yield from gIntercept conn, criteria, instance, operator, ->
            yield from EntityService.gUpdateOneByCriteria(conn, entityName, criteria, instance)

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
    exports.removeNoEditFields entityMeta, @state.user, patch

    patch._modifiedBy = @state.user?._id

    gIntercept = Interceptor.getInterceptor entityName, Interceptor.Actions.Update
    operator = @state.user

    yield from EntityService.gWithTransaction entityMeta, (conn)->
        for p in idVersions
            criteria = {_id: p.id, _version: p._version}
            yield from gIntercept conn, criteria, patch, operator, ->
                yield from EntityService.gUpdateOneByCriteria(conn, entityName, criteria, patch)

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

    criteria = {__type: 'relation', relation: 'and', items: [{field: '_id', operator: 'in', value: ids}]}

    gIntercept = Interceptor.getInterceptor entityName, Interceptor.Actions.Remove
    operator = @state.user

    yield from EntityService.gWithTransaction entityMeta, (conn)->
        yield from gIntercept conn, criteria, operator, ->
            yield from EntityService.gRemoveManyByCriteria(conn, entityName, criteria)
    @status = 204

exports.gRecoverInBatch = ->
    entityName = @params.entityName
    entityMeta = Meta.getEntityMeta(entityName)

    throw new error.UserError('NoSuchEntity') unless entityMeta

    ids = @request.body?.ids
    throw new error.UserError('EmptyOperation') unless ids?.length > 0

    ids = Meta.parseIds(ids, entityMeta)
    throw new error.UserError('EmptyOperation') unless ids.length > 0

    yield from EntityService.gWithTransaction entityMeta, (conn)->
        yield from EntityService.gRecoverMany(conn, entityName, ids)
    @status = 204

exports.gFindOneById = ->
    entityName = @params.entityName
    entityMeta = Meta.getEntityMeta(entityName)

    throw new error.UserError('NoSuchEntity') unless entityMeta

    _id = Meta.parseId @params.id, entityMeta
    return @status = 404 unless _id?

    gIntercept = Interceptor.getInterceptor entityName, Interceptor.Actions.Get
    operator = @state.user

    criteria = {_id}

    entity = yield from EntityService.gWithoutTransaction entityMeta, (conn)->
        yield from gIntercept conn, criteria, operator, ->
            yield from EntityService.gFindOneByCriteria(conn, entityName, criteria, {repo: @query?._repo})

    exports.removeNotShownFields(entityMeta, @state.user, entity)

    entity = Meta.formatEntityToHttp(entity, entityMeta)

    if entity
        @body = entity
    else
        @status = 404

exports.gList = ->
    entityName = @params.entityName
    entityMeta = Meta.getEntityMeta(entityName)
    throw new error.UserError('NoSuchEntity') unless entityMeta

    query = exports.parseListQuery(entityMeta, @query)

    gIntercept = Interceptor.getInterceptor entityName, Interceptor.Actions.List
    operator = @state.user

    r = yield from EntityService.gWithoutTransaction entityMeta, (conn)->
        yield from gIntercept conn, query, operator, ->
            yield from EntityService.gList conn, entityName, query

    exports.removeNotShownFields(entityMeta, @state.user, r.page...)

    page = (Meta.formatEntityToHttp(i, entityMeta) for i in r.page)
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
    entityMeta = Meta.getEntityMeta('F_ListFilters')

    req = @request.body
    return @status = 400 unless req

    instance = Meta.parseEntity(req, entityMeta)

    criteria = {name: instance.name, entityName: instance.entityName}
    includedFields = ['_id', '_version']

    lf = yield from EntityService.gFindOneByCriteria({}, 'F_ListFilters', criteria, {includedFields})
    if lf
        yield from EntityService.gUpdateOneByCriteria({}, 'F_ListFilters', {
            _id: lf._id, _version: lf._version
        }, instance)
    else
        yield from EntityService.gCreate({}, 'F_ListFilters', instance)

    @status = 204

exports.gRemoveFilters = ->
    query = @query
    return @status = 400 unless query and query.name and query.entityName

    yield from EntityService.gRemoveManyByCriteria({}, 'F_ListFilters', {
        name: query.name, entityName: query.entityName
    })

    @status = 204

checkAclField = (user, entityName, fieldName, action)->
    return false unless user
    if user.acl?.field?[entityName]?[fieldName]?[action]
        return true
    if user.roles
        for roleName,role of user.roles
            if role.acl?.field?[entityName]?[fieldName]?[action]
                return true
    false

# 过滤掉不显示的字段
exports.removeNotShownFields = (entityMeta, user, entities...)->
    fields = entityMeta.fields

    removedFieldNames = []
    for fieldName, fieldMeta of fields
        if fieldMeta.type == 'Password'
            removedFieldNames.push fieldName
        else if fieldMeta.notShow
            unless checkAclField user, entityMeta.name, fieldName, 'show'
                removedFieldNames.push fieldName

    if entities?.length and removedFieldNames.length
        for e in entities
            for field in removedFieldNames
                delete e[field]

# 过滤掉不允许创建的字段
exports.removeNoCreateFields = (entityMeta, user, entity)->
    fields = entityMeta.fields

    removedFieldNames = []
    for fieldName, fieldMeta of fields
        if fieldMeta.noCreate
            unless checkAclField user, entityMeta.name, fieldName, 'create'
                removedFieldNames.push fieldName

    if removedFieldNames.length
        for field in removedFieldNames
            delete entity[field]

# 过滤掉不允许编辑的字段
exports.removeNoEditFields = (entityMeta, user, entity)->
    fields = entityMeta.fields

    removedFieldNames = []
    for fieldName, fieldMeta of fields
        if fieldMeta.noEdit || fieldMeta.editReadonly
            unless checkAclField user, entityMeta.name, fieldName, 'edit'
                removedFieldNames.push fieldName

    if removedFieldNames.length
        for field in removedFieldNames
            delete entity[field]