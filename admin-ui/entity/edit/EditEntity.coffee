# 编辑并保存
F.toUpdateEntity = (entityName, _id)->
    pageId = if !_id?
        "create-entity-#{entityName}-" + Date.now()
    else
        "update-entity-#{entityName}-#{_id}"
    isCreate = !_id?
    entityMeta = F.meta.entities[entityName]
    if isCreate
        title = '创建 ' + entityMeta.label
    else
        title = "编辑 #{entityMeta.label} #{F.digestId(_id)}"

    F.openOrAddPage pageId, title, 'F.toUpdateEntity', [entityName, _id], ($page)->
        $view = $(FT.EditEntity()).appendTo($page.find('.page-content'))
        $saveBtn = $view.find('.save:first')
        $saveBtn.html '加载原数据...'

        readyToEdit = false
        form = null
        entityValue = null

        render = (entityValue)->
            form.$form.remove() if form
            form = F.Form.buildRootForm(entityName, entityValue)
            $view.append(form.$form)
            F.loadDigestedEntities(form.$form)

        if isCreate
            $saveBtn.html '保存'
            readyToEdit = true
            render {}
        else
            readyToEdit = false
            q = F.api.get "entity/#{entityName}/#{_id}"
            q.catch (jqxhr)->
                F.removePage(pageId) # 加载失败移除页面
                F.alertAjaxError jqxhr
            q.then (value)->
                entityValue = value
                $saveBtn.html '保存'
                readyToEdit = true
                render value

        saving = false
        $saveBtn.click ->
            return unless readyToEdit and not saving

            entity = {}
            try
                F.Form.collectFormInput(form, entity, isCreate)
            catch e
                F.toastError(e)
                return

            saving = true
            $saveBtn.html '保存中...'

            q = if _id
                F.api.put "entity/#{entityName}/#{_id}", entity
            else
                F.api.post "entity/#{entityName}", entity
            q.then ->
                F.toastSuccess('保存成功')
                F.removePage(pageId)
                $(document.body).find('.refresh-page.refresh-' + entityName).click()
            q.catch (xhr)->
                saving = false
                $saveBtn.html '保存'
                F.alertAjaxError xhr

# TODO win.on 'AfterClosed', -> F.Form.disposeForm(form) if form

# 编辑并返回给调用者
F.openEditEntityDialog = (entityName, entityValue, callback)->
    $view = $(FT.EditEntity())
    form = F.Form.buildRootForm(entityName, entityValue)
    $view.append(form.$form)
    F.loadDigestedEntities(form.$form)

    entityMeta = F.meta.entities[entityName]

    win = F.openModalDialog({content: $view, title: "编辑 #{entityMeta.label}"})
    win.on 'AfterClosed', -> F.Form.disposeForm(form)

    $view.find('.save:first').click ->
        entity = {}
        try
            F.Form.collectFormInput(form, entity)
        catch e
            F.toastError(e)
            return

        callback(entity)
        win.close()

