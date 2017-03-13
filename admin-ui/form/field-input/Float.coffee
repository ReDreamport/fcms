FF = F.Form

FF.Float = {
    buildField: (form, fieldName, $fieldInputSlot, entityInitValue) ->
        FF.buildNormalField(form, fieldName, $fieldInputSlot, entityInitValue, FF.Float.buildFieldItem)

    buildFieldItem: (form, fieldMeta, itemValue)->
        FT.Float({field: fieldMeta, fClass: form.fClass, value: itemValue})

    getInput: (form, fieldName)->
        $field = FF.get$field(form, fieldName)
        values = []
        $field.find(".fw-field-item-input.#{form.fClass}").each ->
            num = $(this).val()
            if num
                num = parseFloat num
                values.push(num)
        FF.normalizeSingleOrArray values, form.entityMeta.fields[fieldName].multiple
}


