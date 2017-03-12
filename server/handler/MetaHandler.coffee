Meta = require '../Meta'
SystemMeta = require '../SystemMeta'

exports.gGetAllMeta = ->
    app = @state.app
    @body = app.meta.getAllMeta()
    yield return

exports.gSaveMeta = ->
    app = @state.app

    type = @params.type
    name = @params.name
    meta = @request.body

    if type == 'entity'
        yield from app.meta.gSaveEntityMeta(name, meta)
    else
        return @status = 400

    @status = 204

exports.gRemoveMeta = ->
    app = @state.app

    type = @params.type
    name = @params.name

    if type == 'entity'
        yield from app.meta.gRemoveEntityMeta(name)
    else
        return @status = 400

    @status = 204

exports.gGetEmptyEntityMeta = ->
    e = {fields: {}, db: Meta.DB.mongo}
    SystemMeta.patchSystemFields(e)
    @body = e
    yield return