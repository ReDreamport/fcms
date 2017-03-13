pageId = 'meta-index'
title = "元数据管理"

F.toMetaIndex = ->
    F.openOrAddPage pageId, title, 'F.toMetaIndex', [], ($page)->
        $view = $(FT.MetaIndex()).appendTo($page.find('.page-content'))

        refreshLists = ->
            $view.find('.entity-list').remove()
            q = F.fetchMeta()
            q.catch F.alertAjaxError
            q.then ->
                $view.append(FT.MetaList())

        refreshLists()

        $view.find('.refresh-list').on 'click', -> refreshLists()

        $view.find('.add-entity').on 'click', ->
            q = F.api.get 'meta/entity/_empty'
            q.catch F.alertAjaxError
            q.then (em)->
                F.toEditEntityMeta null, em

        $view.on 'click', '.entity', ->
            F.toEditEntityMeta $(this).attr('name')

        $view.on 'click', '.remove-entity', ->
            name = $(this).attr('name')
            return unless confirm "确定删除 #{name}？"
            q = F.api.remove 'meta/entity/' + name
            q.catch F.alertAjaxError
            q.then ->
                refreshLists()

        $view.find('.add-option').on 'click', -> false