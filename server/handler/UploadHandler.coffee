path = require 'path'

config = require '../config'
fileUtil = require '../fileUtil'
Meta = require '../Meta'

gUpload = (files, query, app)->
    return false unless files

    file = null
    for field, file of files
        break # 取第一个文件

    return false unless file?

    entityName = query.entityName
    fieldName = query.fieldName

    return false unless entityName and fieldName

    if entityName and fieldName
        fieldMeta = app.meta.getEntityMeta(entityName)?.fields?[fieldName]

    subDir = fieldMeta?.fileStoreDir || "default"
    fileTargetDir = path.join(config.fileDir, app.name, subDir)

    fileFinalFullPath = path.join(fileTargetDir, Meta.newObjectId().toString() + path.extname(file.path))
    yield from fileUtil.gMoveFileTo(file.path, fileFinalFullPath)

    fileRelativePath = path.relative(config.fileDir, fileFinalFullPath)

    {fileRelativePath: fileRelativePath, fileSize: file.size}

# H5上传
exports.gUpload = ->
    app = @state.app
    result = yield from gUpload @request.body.files, @query, app

    if result
        @body = result
    else
        @status = 400

# Transport 上传
exports.gUpload2 = ->
    app = @state.app
    result = yield from gUpload @request.body.files, @query, app
    if result
        result.success = true
    else
        result = {success: false}
    @body = '<textarea data-type="application/json">' + JSON.stringify(result) + '</textarea>'

# WangEditor 使用的图片上传接口
exports.gUploadForRichText = ->
    app = @state.app

    files = @request.body.files
    return @status = 400 unless files
    file = files.f0
    return @status = 400 unless file

    result = yield from exports.gUploadUtil(file, app.name + '/RichText')
    @type = 'text/html'
    @body = config.fileDownloadPrefix + result.fileRelativePath

exports.gUploadUtil = (file, subDir)->
    fileTargetDir = path.join(config.fileDir, subDir)

    fileSize = file.size

    fileFinalFullPath = path.join(fileTargetDir, Meta.newObjectId().toString() + path.extname(file.path))
    yield from fileUtil.gMoveFileTo(file.path, fileFinalFullPath)

    fileRelativePath = path.relative(config.fileDir, fileFinalFullPath)

    {fileRelativePath: fileRelativePath, fileSize: fileSize}


