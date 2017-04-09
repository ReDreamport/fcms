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
                entityNames = (name for name, em of F.meta.entities)
                entityNames.sort()

                viewNames = (name for name, em of F.meta.views)
                viewNames.sort()
                $view.append(FT.MetaList({entityNames, viewNames}))

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

        $view.on 'click', '.check-all', ->
            $this = $(this)
            checked = $this.prop 'checked'
            $this.closest('table').find('input.check').prop 'checked', checked

        $view.on 'click', '.copy-meta', ->
            entities = []
            $('table.entities input.check:checked', $view).each ->
                entities.push F.meta.entities[$(this).attr('name')]
            views = []
            $('table.views input.check:checked', $view).each ->
                views.push F.meta.views[$(this).attr('name')]
            meta = {entities, views}

            $('.meta-copied', $view).val JSON.stringify(meta)

        $view.on 'click', '.paste-meta', ->
            meta = $.trim $('.meta-copied', $view).val()
            return unless meta

            try
                meta = JSON.parse meta
            catch
                F.toastError('解析JSON失败')
                return

            entityNames = (entity.name for entity in meta.entities)
            viewNames = (view.name for view in meta.views)

            return unless confirm "确定导入以下实体：#{entityNames.join(',')}\n以下视图：#{viewNames.join(',')}\n"

            q = F.api.post "meta", meta
            q.catch F.alertAjaxError
            q.then ->
                F.toastSuccess('导入成功')
                $('.view.view-meta-index .refresh-list').click()


