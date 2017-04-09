F.toastNormal = (message, duration)->
    toast message, 'toast-normal', duration

F.toastSuccess = (message, duration)->
    toast message, 'toast-success', duration

F.toastWarning = (message, duration = 3800)->
    toast message, 'toast-warning', duration

F.toastError = (message, duration = 3800)->
    toast message, 'toast-error', duration

toast = (message, extraClass, duration = 2000)->
    $t = $('<div>', class: "toast " + extraClass, html: message).appendTo($('.toast-box'))
        .hide().slideDown(200)
    F.setTimeout duration, ->
        $t.slideUp 200, -> $t.remove()

F.alertAjaxError = (xhr)->
    F.toastError F.parseXhrErrorMessage(xhr)

F.parseXhrErrorMessage = (xhr)->
    try
        xhr.responseText && JSON.parse(xhr.responseText).message || "#{xhr.status}:#{xhr.responseText}"
    catch
        "#{xhr.status}"