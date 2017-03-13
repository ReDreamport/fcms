FF = F.Form

FF.Password = {
    buildField: (form, fieldName, $fieldInputSlot, entityInitValue) ->
        FF.buildNormalField(form, fieldName, $fieldInputSlot, entityInitValue, FF.Password.buildFieldItem)

    buildFieldItem: (form, fieldMeta, itemValue)->
        FT.Password({field: fieldMeta, fClass: form.fClass, value: itemValue})

    getInput: (form, fieldName)->
        $field = FF.get$field(form, fieldName)
        values = []
        $field.find(".fw-field-item-input.#{form.fClass}").each -> values.push($(this).val())
        FF.normalizeSingleOrArray values, form.entityMeta.fields[fieldName].multiple
}


