logs = []

F.log = (message)->
    logs.push {message, timestamp: new Date()}

pageId = "log"
title = "系统日志"

F.showLog = ->
    F.openOrAddPage pageId, title, 'F.showLog', [], ($page)->
        messages = []
        for log in logs
            time = moment(log.timestamp).format('HH:mm:ss.SSS')
            messages.push("[#{time}] " + log.message)
        log = messages.join "\n"

        $('<pre />').html(log).appendTo($page.find('.page-content'))
$ ->
    $('.show-log').click F.showLog

