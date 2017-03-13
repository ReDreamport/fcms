FF = F.Form

FF.Check = {
    buildField: (form, fieldName, $fieldInputSlot, entityInitValue) ->
        FF.buildNormalField(form, fieldName, $fieldInputSlot, entityInitValue, FF.Check.buildFieldItem)

    buildFieldItem: (form, fieldMeta, itemValue)->
        FT.Check({field: fieldMeta, fClass: form.fClass, value: itemValue})

    getInput: (form, fieldName)->
        $field = FF.get$field(form, fieldName)
        values = []
        $field.find(".fw-field-item-input.#{form.fClass}").each -> values.push($(this).prop('checked'))
        FF.normalizeSingleOrArray values, form.entityMeta.fields[fieldName].multiple
}