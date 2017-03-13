Meta = require '../Meta'
SystemMeta = require '../SystemMeta'

exports.gGetAllMeta = ->
    @body = Meta.getAllMeta()
    yield return

exports.gSaveMeta = ->
    type = @params.type
    name = @params.name
    meta = @request.body

    if type == 'entity'
        yield from Meta.gSaveEntityMeta(name, meta)
    else
        return @status = 400

    @status = 204

exports.gRemoveMeta = ->
    type = @params.type
    name = @params.name

    if type == 'entity'
        yield from Meta.gRemoveEntityMeta(name)
    else
        return @status = 400

    @status = 204

exports.gGetEmptyEntityMeta = ->
    e = {fields: {}, db: Meta.DB.mongo}
    SystemMeta.patchSystemFields(e)
    @body = e
    yield return