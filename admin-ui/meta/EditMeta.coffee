editEntityOrView = (editedEntityName, objectName, objectLabel, metaName, funcName)->
    pageId = "edit-" + objectName + "-meta-" + (editedEntityName || Date.now())
    title = editedEntityName && "编辑#{objectLabel} #{editedEntityName}" || "创建新#{objectLabel}"

    F.openOrAddPage pageId, title, funcName, [editedEntityName], ($page)->
        $view = $(FT.EditEntity()).appendTo($page.find('.page-content'))

        $saveBtn = $view.find('.save:first')

        q = if editedEntityName
            F.api.get "meta/#{objectName}/#{editedEntityName}"
        else
            F.api.get 'meta-empty'

        q.catch F.alertAjaxError
        q.then (editedEntityMeta)->
            # 对象转数组
            editedEntityMeta = F.cloneByJSON(editedEntityMeta)
            fields = editedEntityMeta.fields
            fieldArray = (fm for fn, fm of fields)
            editedEntityMeta.fields = fieldArray

            form = F.Form.buildRootForm metaName, editedEntityMeta
            $view.append(form.$form)

            saving = false
            $saveBtn.click ->
                return if saving

                editedEntityMeta = {}
                try
                    F.Form.collectFormInput(form, editedEntityMeta)
                catch e
                    F.toastError(e)
                    return

                # 字段数组转字段对象
                fieldArray = editedEntityMeta.fields
                editedEntityMeta.fields = {}
                editedEntityMeta.fields[fm.name] = fm for fm in fieldArray

                saving = true
                $saveBtn.html '保存中...'

                q = F.api.put "meta/#{objectName}/#{editedEntityMeta.name}", editedEntityMeta
                q.then ->
                    F.removePage(pageId)
                    $('.view.view-meta-index .refresh-list').click()
                q.catch (xhr)->
                    saving = false
                    $saveBtn.html '保存'
                    F.alertAjaxError xhr

F.toEditEntityMeta = (editedEntityName)->
    editEntityOrView editedEntityName, 'entity', '实体', 'F_EntityMeta', 'F.toEditEntityMeta'

F.toEditEntityViewMeta = (editedEntityName)->
    editEntityOrView editedEntityName, 'view', '实体视图', 'F_EntityViewMeta', 'F.toEditEntityViewMeta'
