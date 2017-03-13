pageId = 'promotion-channel'
title = "营销推广渠道配置"

F.toPromotionChannels = ->
    F.openOrAddPage pageId, title, 'F.toPromotionChannels', [], ($page)->
        $view = $(FT.PromotionChannel()).appendTo($page.find('.page-content'))

        F.enablePrintView $view

        $channels = $('.channels', $view)
        $baseUrl = $('.base-url', $view)

        promotionChannels = null

        addChannel = (channel)->
            $row = $ FT.PromotionChannelRow(channel || {})
            $channels.prepend $row

            showQrCode $row.find('.qr-code:first')[0], channel.url if channel?.url

        showQrCode = (node, url)->
            node.innerHTML = ""
            return unless url
            new QRCode(node, {
                text: url,
                width: 128, height: 128,
                colorDark: "#000000", colorLight: "#ffffff", correctLevel: QRCode.CorrectLevel.H
            });

        $view.on 'click', '.remove-row', ->
            $(this).closest('tr').remove()

        $('.do-query', $view).click ->
            promotionName = $.trim $('.promotion-name', $view).val()
            return unless promotionName
            $channels.empty()

            promotionChannels = null
            $status = $('.actions .status', $view).html 'querying...'

            q = F.api.get 'pt/_channels/' + promotionName
            q.catch F.alertAjaxError
            q.then (r)->
                $status.html 'Query ok'
                promotionChannels = r
                promotionChannels.seq = promotionChannels.seq || 1

                $baseUrl.val r.baseUrl

                channels = r.channels || []
                channels = channels.sort (a, b)-> (a.pv || 0) - (b.pv || 0)
                addChannel(c) for c in channels

        $('.add-channel', $view).click ->
            addChannel {}

        generateUrl = ($tr, baseUrl)->
            c = promotionChannels.seq
            promotionChannels.seq++
            url = if baseUrl.indexOf("?") >= 0
                baseUrl + "&_c=" + c
            else
                baseUrl + "?_c=" + c

            $tr.find('.url:first').html(url).attr('href', url).attr('c', c)
            showQrCode $tr.find('.qr-code:first')[0], url

        $('.fill-url', $view).click ->
            baseUrl = $.trim $baseUrl.val()
            return unless baseUrl

            $channels.find('tr').each ->
                $tr = $ this
                $url = $tr.find('.url:first')
                url = $.trim $url.text()
                return if url

                generateUrl $tr, baseUrl

        $('.refresh-url', $view).click ->
            baseUrl = $.trim $baseUrl.val()
            return unless baseUrl

            $channels.find('tr').each ->
                $tr = $ this
                generateUrl $tr, baseUrl

        $('.save', $view).click ->
            unless promotionChannels
                F.toastWarning 'Query Promotion First!'
                return

            promotionName = $.trim $('.promotion-name', $view).val()

            baseUrl = $.trim $baseUrl.val()
            unless baseUrl
                F.toastWarning 'Base Url is required!'
                return

            channels = []
            $channels.find('tr').each ->
                $tr = $ this
                name = $.trim $tr.find('.channel-name').val()
                $url = $tr.find('.url')
                url = $.trim $url.text()
                c = $url.attr('c')
                unless name and url
                    channels = false
                    return
                channels.push {name, url, c}

            unless channels
                F.toastWarning 'Name and url must all filled!'
                return

            promotionChannels.seq++
            promotionChannels._id = promotionName
            promotionChannels.baseUrl = baseUrl
            promotionChannels.channels = channels

            q = F.api.put 'pt/_channels/' + promotionName, promotionChannels
            q.catch F.alertAjaxError
            q.then (r)-> F.toastSuccess '成功'

        $('.import-channel', $view).click ->
            names = $('.channel-names').val()
            names = names.split /[|,\n\r]/
            for name in names
                n2 = $.trim name
                addChannel({name: n2}) if n2

        $('.show-qr-code').click ->
            checked = $(this).prop('checked')
            if checked
                $view.find('table .qr-code').show()
            else
                $view.find('table .qr-code').hide()

        $('.show-stats').click ->
            checked = $(this).prop('checked')
            if checked
                $view.find('table .status').show()
            else
                $view.find('table .status').hide()









