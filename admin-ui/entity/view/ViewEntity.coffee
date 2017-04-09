# 编辑并保存
F.toViewEntity = (entityName, _id)->
    pageId = "view-entity-#{entityName}-#{_id}"
    entityMeta = F.meta.entities[entityName]
    title = "#{entityMeta.label} - #{F.digestId(_id)}"

    F.openOrAddPage pageId, title, 'F.toViewEntity', [entityName, _id], ($page)->
        $view = $(FT.ViewEntity({entityName, _id})).appendTo($page.find('.page-content'))

        allFields = entityMeta.fields
        fields = {}
        for fn, fm of allFields
            continue if fm.type == 'Password'
            continue if fm.notShow and not F.checkAclField(entityMeta.name, fn, 'show')

            fields[fn] = fm

        entityValue = null
        q = F.api.get "entity/#{entityName}/#{_id}"
        q.catch (jqxhr)->
            F.removePage(pageId) # 加载失败移除页面
            F.alertAjaxError jqxhr
        q.then (value)->
            entityValue = value
            $view.append FT.ViewEntityFields({entityValue, fields})
            F.loadDigestedEntities($view)

        $view.find('.remove-entity').click ->
            _id = $(this).attr("_id")
            q = F.api.remove "entity/#{entityName}?_ids=#{_id}"
            q.catch F.alertAjaxError
            q.then ->
                F.toastSuccess('删除成功')
                F.removePage(pageId)

        $view.find('.to-update-entity').click -> F.removePage(pageId)