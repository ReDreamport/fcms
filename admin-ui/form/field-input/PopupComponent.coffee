FF = F.Form

FF.PopupComponent = {
    buildField: (form, fieldName, $fieldInputSlot, entityInitValue) ->
        $field = $fieldInputSlot.closest('.fw-field')
        fieldMeta = form.entityMeta.fields[fieldName]
        fieldInitValue = entityInitValue?[fieldName]
        fieldValue = !fieldMeta.multiple && [fieldInitValue] || fieldInitValue || []

        refEntityMeta = F.meta.entities[fieldMeta.refEntity]
        listFieldNames = F.getListFieldNames refEntityMeta.fields
        $fieldInput = $ FT.PopupComponent({field: fieldMeta, fieldValue, fClass: form.fClass, listFieldNames})
        $fieldInputSlot.append($fieldInput)
        $tbody = $fieldInput.find('tbody:first')

        $field.on 'click', '.fw-add-item-component', (e)-> # 多值，添加一项
            $tbody.append FT.PopupComponentItem({itemValue: {}, field: fieldMeta, fClass: form.fClass, listFieldNames})

            e.stopPropagation()
            e.preventDefault()
            false

        $fieldInput.on 'click', '.fw-remove-item-component', (e)-> # 多值，删除一项
            $item = $(this).closest('tr')
            $item.find('.form').each -> FF.disposeForm(FF.$formToForm($(this)))
            $item.remove()

            e.stopPropagation()
            e.preventDefault()
            false

        $field.on 'click', '.fw-remove-all-item-component', (e)-> # 多值，删除所有项
            $tbody.find('.form').each -> FF.disposeForm(FF.$formToForm($(this)))
            $tbody.empty()

            e.stopPropagation()
            e.preventDefault()
            false

        $field.on 'click', '.fw-hide-all-item-component', (e)->
            FF.toggleVisible($(this), $tbody)

            e.stopPropagation()
            e.preventDefault()
            false

        $fieldInput.on 'click', '.fw-edit-item-component', (e)-> # 编辑项
            $tr = $(this).closest('tr')
            itemValue = $tr.attr('itemValue')
            itemValue = itemValue && JSON.parse(itemValue) || {}

            $closestView = $fieldInput.closest('.view')
            F.openEditEntityDialog fieldMeta.refEntity, itemValue, (entityValue)->
                $item = $ FT.PopupComponentItem({
                    itemValue: entityValue, field: fieldMeta, fClass: form.fClass,
                    listFieldNames
                })
                $tr.replaceWith $item
                FF.FieldInputChangeEventManager.fire(form.fid, fieldName) # 触发事件

            e.stopPropagation()
            e.preventDefault()
            false

    getInput: (form, fieldName)->
        $field = FF.get$field(form, fieldName)
        values = []
        $field.find("tr.fw-field-item.#{form.fClass}").each ->
            iv = $(this).attr('itemValue')
            values.push JSON.parse(iv) if iv
        FF.normalizeSingleOrArray values, form.entityMeta.fields[fieldName].multiple
}