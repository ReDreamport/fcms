error = require '../error'
Meta = require '../Meta'
EntityService = require '../service/EntityService'

bridges = {}

getBridge = (entityMeta)->
    bridges[entityMeta.name]

exports.gCreate = (entityMeta, entityInput)->
    bridge = getBridge(entityMeta)?.gCreate
    return entityMeta unless bridge

    yield from bridge entityMeta, entityInput

exports.gUpdate = (entityMeta, entityInput, entityId)->
    bridge = getBridge(entityMeta)?.gUpdate
    return entityMeta unless bridge

    yield from bridge entityMeta, entityInput, entityId

exports.gUpdateInBatch = (entityMeta, entityInput, idVersions)->
    bridge = getBridge(entityMeta)?.gUpdateInBatch
    return entityMeta unless bridge

    yield from bridge entityMeta, entityInput, idVersions

exports.gDeleteInBatch = (entityMeta, ids)->
    bridge = getBridge(entityMeta)?.gDeleteInBatch
    return entityMeta unless bridge

    yield from bridge entityMeta, ids

exports.gRecoverInBatch = (entityMeta, ids)->
    bridge = getBridge(entityMeta)?.gRecoverInBatch
    return entityMeta unless bridge

    yield from bridge entityMeta, ids

exports.gAfterFindOne = (entityMeta, entity, operatorId)->
    bridge = getBridge(entityMeta)?.gAfterFindOne
    return unless bridge

    yield from bridge entityMeta, entity, operatorId

exports.gModifyListQuery = (entityMeta, query, operatorId)->
    bridge = getBridge(entityMeta)?.gModifyListQuery
    return unless bridge

    yield from bridge entityMeta, query, operatorId

bridges.StoreProduct =
    onCreate: (entityMeta, entityInput)->
        _createdBy = entityInput._createdBy

        # 根据员工查所在店铺
        store = yield from EntityService.gFindOneByCriteria(null, Meta.getEntityMeta('Store'), {staff: _createdBy},
            {includeFields: ['_id']})
        throw new error.UserError 'NotStaff', '无员工权限' unless store?
        entityInput.store = store._id

        entityMeta = Meta.getEntityMeta('GlobalProduct')
        entityMeta

    onUpdate: (entityMeta, entityInput, entityId)->
        _modifiedBy = entityInput._modifiedBy
        delete entityInput.store

        # 根据员工查所在店铺
        storeOfModifier = yield from EntityService.gFindOneByCriteria(null, Meta.getEntityMeta('Store'), {staff: _modifiedBy},
            {includeFields: ['_id']})
        throw new error.UserError 'NotStaff', '无员工权限' unless storeOfModifier?

        globalProduct = yield from EntityService.gFindOneById(null, Meta.getEntityMeta('GlobalProduct'), entityId,
            {includeFields: ['store']})
        throw new error.UserError 'NoSuchProduct', '无此商品' unless globalProduct?

        unless globalProduct.store.toString() == storeOfModifier._id.toString()
            throw new error.UserError 'NotYourProduct', '您没有修改该商品的权限'

        entityMeta = Meta.getEntityMeta('GlobalProduct')
        {entityMeta, entityInput}


