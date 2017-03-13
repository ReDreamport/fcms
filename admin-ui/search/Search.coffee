pageId = 'configElasticSearch'
title = "配置ES"

F.configElasticSearch = ->
    F.openOrAddPage pageId, title, 'F.configElasticSearch', [], ($page)->
        $view = $(FT.ConfigElasticSearch()).appendTo($page.find('.page-content'))

        $r = $('.response', $view).empty()

        $history = $('.history', $view)
        history = localStorage.getItem('es-history')
        history = history && JSON.parse(history) || []

        renderHistory = ->
            $history.empty()
            for h,index in history
                $history.prepend FT.EsHistoryItem({title: "[#{h.method}] #{h.path}", index})
        renderHistory()

        addHistory = (data)->
            history.push data
            localStorage.setItem("es-history", JSON.stringify(history))
            renderHistory()

        $history.on 'click', '.remove', ->
            $this = $(this)
            index = $this.attr 'index'
            history.splice(index, 1)
            localStorage.setItem("es-history", JSON.stringify(history))
            renderHistory()

        $history.on 'click', '.title', ->
            $this = $(this)
            index = $this.attr 'index'
            i = history[parseInt(index, 10)]

            $('.method', $view).val(i.method)
            $('.path', $view).val(i.path)
            $('.body', $view).val(i.body && JSON.stringify(i.body, null, 4))

        $('.send', $view).click ->
            $r.empty()
            method = $('.method', $view).val()
            path = $('.path', $view).val()
            body = $('.body', $view).val()

            try
                body = JSON.parse(body) if body
            catch e
                F.toastError('JSON 格式错误')
                return

            data = {method, path, body}
            addHistory(data)

            q = F.api.post 'config-es', data
            q.catch F.alertAjaxError
            q.then (r)->
                $r.html JSON.stringify(r, null, 4)






