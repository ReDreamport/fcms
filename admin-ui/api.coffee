api = {}
F.api = api

apiRoot = '/'

F.apiRoot = apiRoot

F.resourceRoot = '/r/'

F.setApiRoot = (url)->
    apiRoot = url
    localStorage.setItem('apiRoot', url)

F.setResourceRoot = (url)->
    resourceRoot = url
    localStorage.setItem('resourceRoot', url)

AjaxOption = (type, data, settings) ->
    @type = type

    if type == "POST" || type == "PUT" || type == "DELETE"
        @data = data && JSON.stringify(data)
        @contentType = "application/json"
    else
        @data = data

    this.beforeSend = (request) -> true

    @cache = false; # !!!

    F.extend(this, settings) if settings?

fail = (jqxhr)->
    console.log('Got Ajax fail ' + jqxhr.status)
    if jqxhr.status == 401
        console.log("401, to sign in")
        # F.toSignIn()
        r = jqxhr.responseText && JSON.parse(jqxhr.responseText)
        href = encodeURIComponent(location.href)
        location.href = r.signInUrl + "?callback=#{href}"
    else if jqxhr.status == 403
        F.toastError '需要权限！'

    throw jqxhr

api.get = (relativeUrl, data, settings) ->
    q = Promise.resolve $.ajax(apiRoot + relativeUrl, new AjaxOption("GET", data, settings))
    q.catch fail

api.getAbsolute = (absoluteUrl, data, settings) ->
    q = Promise.resolve $.ajax(absoluteUrl, new AjaxOption("GET", data, settings))
    q.catch fail

api.post = (relativeUrl, data, settings) ->
    q = Promise.resolve $.ajax(apiRoot + relativeUrl, new AjaxOption("POST", data, settings))
    q.catch fail

api.put = (relativeUrl, data) ->
    q = Promise.resolve $.ajax(apiRoot + relativeUrl, new AjaxOption("PUT", data))
    q.catch fail

api.remove = (relativeUrl, data) ->
    q = Promise.resolve $.ajax(apiRoot + relativeUrl, new AjaxOption("DELETE", data))
    q.catch fail

api.upload = ($file, entityName, fieldName, callback)->
    if window.FormData
        files = $file[0].files
        return callback(false) unless files && files.length
        for file in files
            uploadByH5(file, entityName, fieldName, callback)
    else
        uploadByTransport($file, entityName, fieldName, callback)

uploadByH5 = (fileObject, entityName, fieldName, callback)->
    xhr = new XMLHttpRequest()
    xhr.open "POST", apiRoot + "file?entityName=#{entityName}&fieldName=#{fieldName}"

    xhr.onload = (e)->
        switch xhr.status
            when 200
                response = xhr.responseText && JSON.parse xhr.responseText
                path = response.fileRelativePath
                size = response.fileSize
                callback true, {path, size}
            when 413
                callback false
                F.toastError "文件大小超过限制！"
            else
                callback false
                F.toastError "上传失败[#{xhr.status}]。"
    xhr.onerror = (e)->
        console.log(e)
        callback false
        F.toastError '上传失败，遇到错误！'

    data = new FormData()
    data.append("f0", fileObject)
    xhr.send data

uploadByTransport = ($file, entityName, fieldName, callback)->
    url = apiRoot + "file2?entityName=#{entityName}&fieldName=#{fieldName}"
    options = {type: 'POST', files: $file, iframe: true, dataType: 'json', processData: false}
    $.ajax(url, options).complete (xhr) ->
        if xhr.responseText.indexOf('413 Request Entity Too Large') >= 0
            callback false
            F.toastError "文件大小超过限制！"
        else if xhr.responseJSON
            response = xhr.responseJSON
            if response.success
                path = response.fileRelativePath
                size = response.fileSize
                callback true, {path, size}
            else
                callback false
                F.toastError "上传失败"
        else
            callback false
            F.toastError "上传失败"
