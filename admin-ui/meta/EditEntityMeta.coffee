F.toEditEntityMeta = (entityNameAsId, emptyEntityMeta)->
    pageId = "edit-entity-meta-" + (entityNameAsId || Date.now())
    title = entityNameAsId && "编辑实体 #{entityNameAsId}" || '创建新实体'

    F.openOrAddPage pageId, title, 'F.toEditEntityMeta', [entityNameAsId, emptyEntityMeta], ($page)->
        $view = $(FT.EditEntity()).appendTo($page.find('.page-content'))

        $saveBtn = $view.find('.save:first')

        entityMetaAsEntityValue = entityNameAsId && F.meta.entities[entityNameAsId] || emptyEntityMeta || {}

        # 对象转数组
        entityMetaAsEntityValue = F.cloneByJSON(entityMetaAsEntityValue)
        fields = entityMetaAsEntityValue.fields
        fieldArray = (fm for fn, fm of fields)
        entityMetaAsEntityValue.fields = fieldArray

        form = F.Form.buildRootForm 'F_EntityMeta', entityMetaAsEntityValue
        $view.append(form.$form)

        # win.on 'AfterClosed', -> F.Form.disposeForm(form) if form

        saving = false
        $saveBtn.click ->
            return if saving

            entityMetaAsEntityValue = {}
            F.Form.collectFormInput(form, entityMetaAsEntityValue)

            # 字段数组转字段对象
            fieldArray = entityMetaAsEntityValue.fields
            entityMetaAsEntityValue.fields = {}
            entityMetaAsEntityValue.fields[fm.name] = fm for fm in fieldArray

            saving = true
            $saveBtn.html '保存中...'

            q = F.api.put 'meta/entity/' + entityMetaAsEntityValue.name, entityMetaAsEntityValue
            q.then ->
                F.removePage(pageId)
            q.catch (xhr)->
                saving = false
                $saveBtn.html '保存'
                F.alertAjaxError xhr


