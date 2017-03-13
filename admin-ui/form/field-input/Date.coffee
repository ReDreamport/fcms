FF = F.Form

FF.Date = {
    buildField: (form, fieldName, $fieldInputSlot, entityInitValue) ->
        FF.buildNormalField(form, fieldName, $fieldInputSlot, entityInitValue, FF.Date.buildFieldItem)

    buildFieldItem: (form, fieldMeta, itemValue)->
        FT.Date({field: fieldMeta, fClass: form.fClass, value: itemValue})

    getInput: (form, fieldName)->
        $field = FF.get$field(form, fieldName)
        values = []
        $field.find(".fw-field-item-input.#{form.fClass}").each ->
            v = $(this).val()
            values.push(F.dateStringToInt(v, 'YYYY-MM-DD')) if v
        FF.normalizeSingleOrArray values, form.entityMeta.fields[fieldName].multiple
}