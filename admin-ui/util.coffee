F.setTimeout = (time, callback) ->
    setTimeout(callback, time)

F.objectSize = (object) ->
    return 0 unless object
    count = 0
    count++ for key,v of object
    count

F.objectKeys = (object)->
    return [] unless object
    keys = []
    for key, v of object
        keys.push key
    keys

F.removeFromArray = (array, value)->
    for v, index in array
        if v == value
            array.splice(index, 1)
            return true
    false

uniqueIdNext = 0
F.uniqueId = -> ++uniqueIdNext

F.cloneByJSON = (source)-> JSON.parse(JSON.stringify(source))

F.ofPropertyPath = (root, path)->
    parts = path.split('.')
    start = root
    for part in parts
        return start unless start?
        start = start?[part]
    start

F.extend = (toObject, fromObject)->
    for key, value of fromObject
        toObject[key] = value

F.isNumberType = (value)-> typeof value == 'number'

F.isArray = (value) -> $.isArray value

F.trim = (string)->
    return string unless string?
    string.replace(/^\s+|\s+$/g, '') || ''

# 结果可能为 null, undefined, NaN
F.stringToInt = (string, alternative)->
    return string if F.isNumberType(string)

    unless string?
        return if alternative? then alternative else string # 返回 alternative 或原样返回 null/undefined

    value = parseInt string, 10
    # 处理 NaN，未处理正负无穷
    return 0 if value == 0
    return if alternative? then alternative else value

F.formatDate = (v, format) ->
    return "" unless v?
    d = moment(v)
    d.format(format)

F.dateStringToInt = (val, format)->
    val = F.trim val
    return undefined unless val
    moment(val, format).valueOf()

F.equalOrContainInArray = (target, valueOrArray)->
    return false unless valueOrArray?
    return true if target == valueOrArray

    target in valueOrArray

F.replaceEmptyArray = (test, alt)-> test && test.length && test || alt

F.ensureValueIsArray = (value)->
    if F.isArray(value)
        value
    else
        if value? then [value] else []

F.setIfNone = (object, field, alt)->
    v = object[field]
    return v if v?
    object[field] = alt
    return alt

F.digestId = (id)->
    if id
        id[0] + "..." + id.substring(id.length - 6)
    else ""

F.fileObjectToLink = (obj)->
    path = obj?.path
    path && F.resourceRoot + path || ""

F.showFileSize = (size)->
    return '?' unless size?
    if size < 1024
        size + ' B'
    else if size < 1024 * 1024
        (size / 1024).toFixed(2) + 'KB'
    else if size < 1024 * 1024 * 1024
        (size / 1024 / 1024).toFixed(2) + 'MB'
    else
        (size / 1024 / 1024 / 1024).toFixed(2) + 'GB'

F.removeSystemFields = (fields)->
    fs = F.cloneByJSON(fields)
    delete fs._id
    delete fs._version
    delete fs._createdOn
    delete fs._createdBy
    delete fs._modifiedOn
    delete fs._modifiedBy
    fs

F.getListFieldNames = (fields)->
    names = []
    for fieldName, fm of fields
        continue if fm.hideInListPage
        continue if fieldName in ['_id', '_version', '_createdOn', '_createdBy', '_modifiedOn', '_modifiedBy']
        names.push fieldName
    names

F.isSortableField = (fieldMeta)->
    (fieldMeta.name != '_id' and fieldMeta.name != '_version' and not fieldMeta.multiple and
        fieldMeta.type != 'Reference' and fieldMeta.type != 'Image' and fieldMeta.type != 'File' and
        fieldMeta.type != 'Component' and fieldMeta.type != 'Password')

F.isFieldOfTypeDateOrTime = (fieldMeta)->
    type = fieldMeta.type
    type == 'Date' || type == 'Time' || type == 'DateTime'

F.isFieldOfTypeNumber = (fieldMeta)->
    fieldMeta.type == 'Int' || fieldMeta.type == 'Float'

F.isFieldOfInputTypeOption = (fieldMeta)->
    fieldMeta.inputType == 'Select' || fieldMeta.inputType == 'CheckList'

F.enablePrintView = ($view)->
    $view.find('.print-view').click ->
        $print = $('<div>', class: 'print-overlay')
        $(document.body).append $print
        $print.append $view.clone()
        $print.on 'mousedown', ->
            $print.remove()

F.hasEntityPermission = (action, entityName)->
    user = F.user
    return true if user.admin
    e = user.acl?.entity?[entityName]
    return true if e and (e[action] || e['*'])
    if user.roles
        for rn, role of user.roles
            e = role.acl?.entity?[entityName]
            return true if e and (e[action] || e['*'])

    false

F.checkAclField = (entityName, fieldName, action)->
    user = F.user
    return false unless user
    if user.acl?.field?[entityName]?[fieldName]?[action]
        return true
    if user.roles
        for roleName,role of user.roles
            if role.acl?.field?[entityName]?[fieldName]?[action]
                return true
    false

F.optionsArrayToMap = (options)->
    map = {}
    for o in options
        map[o.name] = o.label
    map

F.assign = (sources...)->
    r = {}
    for s in sources
        r[k] = v for k,v of s
    r
