pageId = 'meta-index'
title = "元数据管理"

F.toMetaIndex = ->
    F.openOrAddPage pageId, title, 'F.toMetaIndex', [], ($page)->
        $view = $(FT.MetaIndex()).appendTo($page.find('.page-content'))

        refreshLists = ->
            $view.find('.list').remove()
            q = F.fetchMeta()
            q.catch F.alertAjaxError
            q.then ->
                $view.append(FT.MetaList())

        refreshLists()

        $view.find('.refresh-list').on 'click', -> refreshLists()

        $view.find('.add-entity').on 'click', -> F.toEditEntityMeta null

        $view.on 'click', '.entity', -> F.toEditEntityMeta $(this).attr('name')

        $view.on 'click', '.remove-entity', ->
            name = $(this).attr('name')
            return unless confirm "确定删除 #{name}？"
            q = F.api.remove 'meta/entity/' + name
            q.catch F.alertAjaxError
            q.then -> refreshLists()

        $view.find('.add-view').on 'click', -> F.toEditEntityViewMeta null

        $view.on 'click', '.view', -> F.toEditEntityViewMeta $(this).attr('name')

        $view.on 'click', '.remove-view', ->
            name = $(this).attr('name')
            return unless confirm "确定删除 #{name}？"
            q = F.api.remove 'meta/view/' + name
            q.catch F.alertAjaxError
            q.then -> refreshLists()