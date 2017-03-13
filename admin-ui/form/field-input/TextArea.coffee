FF = F.Form

FF.TextArea = {
    buildField: (form, fieldName, $fieldInputSlot, entityInitValue) ->
        FF.buildNormalField(form, fieldName, $fieldInputSlot, entityInitValue, FF.TextArea.buildFieldItem)

    buildFieldItem: (form, fieldMeta, itemValue)->
        FT.TextArea({field: fieldMeta, fClass: form.fClass, value: itemValue})

    getInput: (form, fieldName)->
        $field = FF.get$field(form, fieldName)
        values = []
        $field.find(".fw-field-item-input.#{form.fClass}").each -> values.push($(this).val())
        FF.normalizeSingleOrArray values, form.entityMeta.fields[fieldName].multiple
}