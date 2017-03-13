path = require 'path'

config = require '../config'
fileUtil = require '../fileUtil'
Meta = require '../Meta'

gUpload = (files, query)->
    return false unless files

    file = null
    for field, file of files
        break # 取第一个文件

    return false unless file?

    entityName = query.entityName
    fieldName = query.fieldName

    return false unless entityName and fieldName

    if entityName and fieldName
        fieldMeta = Meta.getEntityMeta(entityName)?.fields?[fieldName]

    subDir = fieldMeta?.fileStoreDir || "default"
    fileTargetDir = path.join(config.fileDir, subDir)

    fileFinalFullPath = path.join(fileTargetDir, Meta.newObjectId().toString() + path.extname(file.path))
    yield from fileUtil.gMoveFileTo(file.path, fileFinalFullPath)

    fileRelativePath = path.relative(config.fileDir, fileFinalFullPath)

    {fileRelativePath: fileRelativePath, fileSize: file.size}

# H5上传
exports.gUpload = ->
    result = yield from gUpload @request.body.files, @query

    if result
        @body = result
    else
        @status = 400

# Transport 上传
exports.gUpload2 = ->
    result = yield from gUpload @request.body.files, @query
    if result
        result.success = true
    else
        result = {success: false}
    @body = '<textarea data-type="application/json">' + JSON.stringify(result) + '</textarea>'

# WangEditor 使用的图片上传接口
exports.gUploadForRichText = ->
    files = @request.body.files
    return @status = 400 unless files
    file = files.f0
    return @status = 400 unless file

    result = yield from exports.gUploadUtil(file, 'RichText')
    @type = 'text/html'
    @body = config.fileDownloadPrefix + result.fileRelativePath

exports.gUploadUtil = (file, subDir)->
    fileTargetDir = path.join(config.fileDir, subDir)

    fileSize = file.size

    fileFinalFullPath = path.join(fileTargetDir, Meta.newObjectId().toString() + path.extname(file.path))
    yield from fileUtil.gMoveFileTo(file.path, fileFinalFullPath)

    fileRelativePath = path.relative(config.fileDir, fileFinalFullPath)

    {fileRelativePath: fileRelativePath, fileSize: fileSize}


