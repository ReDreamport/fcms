Meta = require '../Meta'
SystemMeta = require '../SystemMeta'

exports.gGetAllMeta = ->
    @body = Meta.getMetaForFront()
    yield return

exports.gGetMeta = ->
    type = @params.type
    name = @params.name

    if type == 'entity'
        @body = Meta.getEntities()[name]
    else if type == 'view'
        @body = Meta.getViews()[name]
    else
        @status = 400

    yield return

exports.gSaveMeta = ->
    type = @params.type
    name = @params.name
    meta = @request.body

    if type == 'entity'
        yield from Meta.gSaveEntityMeta(name, meta)
    else if type == 'view'
        yield from Meta.gSaveViewMeta(name, meta)
    else
        return @status = 400

    @status = 204

exports.gImportMeta = ->
    meta = @request.body

    for e in meta.entities
        delete e._id
        yield from Meta.gSaveEntityMeta(e.name, e)

    for v in meta.views
        delete v._id
        yield from Meta.gSaveViewMeta(v.name, v)

    @status = 204


exports.gRemoveMeta = ->
    type = @params.type
    name = @params.name

    if type == 'entity'
        yield from Meta.gRemoveEntityMeta(name)
    else if type == 'view'
        yield from Meta.gRemoveViewMeta(name)
    else
        return @status = 400

    @status = 204

exports.gGetEmptyEntityMeta = ->
    e = {fields: {}, db: Meta.DB.mongo}
    SystemMeta.patchSystemFields(e)
    @body = e
    yield return

exports.gGetActions = ->
    @body = Meta.actions
    yield return