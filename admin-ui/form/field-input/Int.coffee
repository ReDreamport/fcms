FF = F.Form

FF.Int = {
    buildField: (form, fieldName, $fieldInputSlot, entityInitValue) ->
        FF.buildNormalField(form, fieldName, $fieldInputSlot, entityInitValue, FF.Int.buildFieldItem)

    buildFieldItem: (form, fieldMeta, itemValue)->
        FT.Int({field: fieldMeta, fClass: form.fClass, value: itemValue})

    getInput: (form, fieldName)->
        $field = FF.get$field(form, fieldName)
        values = []
        $field.find(".fw-field-item-input.#{form.fClass}").each ->
            num = $(this).val()
            if num
                num = parseInt num, 10
                values.push(num)
        FF.normalizeSingleOrArray values, form.entityMeta.fields[fieldName].multiple
}


