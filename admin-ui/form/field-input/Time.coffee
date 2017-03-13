FF = F.Form

FF.Time = {
    buildField: (form, fieldName, $fieldInputSlot, entityInitValue) ->
        FF.buildNormalField(form, fieldName, $fieldInputSlot, entityInitValue, FF.Time.buildFieldItem)

    buildFieldItem: (form, fieldMeta, itemValue)->
        FT.Time({field: fieldMeta, fClass: form.fClass, value: itemValue})

    getInput: (form, fieldName)->
        $field = FF.get$field(form, fieldName)
        values = []
        $field.find(".fw-field-item-input.#{form.fClass}").each ->
            v = $(this).val()
            values.push(F.dateStringToInt(v, 'HH:mm')) if v
        FF.normalizeSingleOrArray values, form.entityMeta.fields[fieldName].multiple
}