Meta = require '../Meta'
SystemMeta = require '../SystemMeta'

exports.gGetAllMeta = ->
    @body = Meta.getMetaForFront()
    yield return

exports.gGetMeta = ->
    type = @params.type
    name = @params.name

    if type == 'entity'
        @body = Meta.getMetaCache().entities[name]
    else if type == 'view'
        @body = Meta.getMetaCache().views[name]
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