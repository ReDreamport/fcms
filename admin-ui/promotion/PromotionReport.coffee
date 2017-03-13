pageId = 'promotion-report'
title = "营销推广分享PV报告"

F.toPromotionReport = ->
    F.openOrAddPage pageId, title, 'F.toPromotionReport', [], ($page)->
        $view = $(FT.PromotionReport()).appendTo($page.find('.page-content'))

        $report = $('.report', $view)
        $timepoints = $('.timepoints', $view).empty()

        report = null

        $('.do-report', $view).click ->
            promotionName = $.trim $('.promotion-name', $view).val()
            return unless promotionName
            $report.empty()

            q = F.api.get 'pt/_report/' + promotionName
            q.catch F.alertAjaxError
            q.then (r)->
                report = r

                $timepoints.empty()
                timepoints = F.objectKeys(r.viewCounts)
                for timepoint in timepoints
                    $timepoints.append FT.PromotionReportTimePoint({timepoint: timepoint})
                $('.timepoint:last', $timepoints).prop('checked', true)

                $report.empty()
                buildNode $report, r.shareTree

        buildNode = ($parent, channel)->
            channelName = channel.name
            childrenCount = channel.children.length
            timepoint = $('.timepoint:checked', $timepoints).val() || '_all'
            viewCount = report.viewCounts[timepoint][channelName]

            unless viewCount?.pv
                console.log('pv=0', timepoint, channelName)

            $parent.append FT.PromotionReportNode({
                name: channelName,
                pv: viewCount?.viewCount, uv: viewCount?.userCount, ip: viewCount?.ipCount, childrenCount
            })

        $timepoints.on 'click', '.timepoint', ->
            $report.empty()
            buildNode($report, report.shareTree)

        $view.on 'click', '.channel-name', ->
            $this = $(this)
            channelName = $this.attr 'name'
            channel = report.nodes[channelName]

            $channel = $this.closest('.channel')
            if $channel.hasClass 'expanded'
                $channel.removeClass 'expanded'
                $channel.children('.children').html "[#{channel.children.length}]"
            else
                $channel.addClass 'expanded'
                $children = $channel.children('.children').empty()

                for child in channel.children
                    buildNode $children, child









