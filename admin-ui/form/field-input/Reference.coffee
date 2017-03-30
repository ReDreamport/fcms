FF = F.Form

FF.Reference = {
    buildField: (form, fieldName, $fieldInputSlot, entityInitValue) ->
        $field = $fieldInputSlot.closest('.fw-field')
        fieldMeta = form.entityMeta.fields[fieldName]
        fieldInitValue = entityInitValue[fieldName]
        refEntityMeta = F.meta.entities[fieldMeta.refEntity]

        $fieldInputSlot.html(FT.Reference({field: fieldMeta, fClass: form.fClass}))
        $refs = $fieldInputSlot.find('.refs:first')

        buildRefItem = (idOrIds)->
            return unless idOrIds?

            if F.isArray idOrIds
                for id in idOrIds
                    $refs.append FT.ReferenceItem(fClass: form.fClass, entityMeta: refEntityMeta, id: id)
            else
                ii = FT.ReferenceItem(fClass: form.fClass, entityMeta: refEntityMeta, id: idOrIds)
                $refs.html ii

            F.loadDigestedEntities($refs)

        buildRefItem fieldInitValue
        if fieldInitValue
            if fieldMeta.multiple
                $refs.attr('value', JSON.stringify(fieldInitValue))
            else
                $refs.attr('value', fieldInitValue)

        $field.on 'click', '.fw-add-ref', (e)-> # 多值，添加一项
            e.stopPropagation()
            e.preventDefault()

            $closestView = $fieldInputSlot.closest('.view')
            multipleOption = fieldMeta
            selectedEntityIds = FF.Reference.getInput form, fieldName
            selectedEntityIds = F.ensureValueIsArray selectedEntityIds
            F.toSelectEntity refEntityMeta.name, multipleOption, selectedEntityIds, (idOrIds)->
                if fieldMeta.multiple
                    ids = selectedEntityIds.concat(idOrIds)
                    $refs.attr('value', JSON.stringify(ids))
                else
                    $refs.attr('value', idOrIds)
                    $refs.empty()

                buildRefItem idOrIds
            false

        $fieldInputSlot.on 'click', '.fw-remove-ref', (e)-> # 多值，删除一项
            $item = $(this).closest('.ref-item')
            $item.remove()

            if fieldMeta.multiple
                ids = []
                $refs.find('.ref-item.' + form.fClass).each -> ids.push($(this).attr('id'))
                $refs.attr('value', JSON.stringify(ids))
            else
                $refs.attr('value', '')

            e.stopPropagation()
            e.preventDefault()
            false

        $field.on 'click', '.fw-remove-all-ref', (e)-> # 多值，删除所有项
            $refs.empty()
            $refs.attr('value', "")

            e.stopPropagation()
            e.preventDefault()
            false

        $field.on 'click', '.fw-hide-all-ref', (e)->
            FF.toggleVisible($(this), $refs)

            e.stopPropagation()
            e.preventDefault()
            false

    getInput: (form, fieldName)->
        values = FF.get$field(form, fieldName).find('.refs:first').attr('value')
        multiple = form.entityMeta.fields[fieldName].multiple
        if multiple
            values = values && JSON.parse(values) || []
        else
            values || undefined
}