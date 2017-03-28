FF = F.Form

FF.DateTime = {
    buildField: (form, fieldName, $fieldInputSlot, entityInitValue) ->
        FF.buildNormalField(form, fieldName, $fieldInputSlot, entityInitValue, FF.DateTime.buildFieldItem)

    buildFieldItem: (form, fieldMeta, itemValue)->
        FT.DateTime({field: fieldMeta, fClass: form.fClass, value: itemValue})

    getInput: (form, fieldName)->
        $field = FF.get$field(form, fieldName)
        values = []
        $field.find(".fw-field-item-input.#{form.fClass}").each ->
            $this = $ this
            v1 = $this.find('>.date-part').val()
            v2 = $this.find('>.time-part').val() || '00:00'
            values.push(F.dateStringToInt(v1 + " " + v2, 'YYYY-MM-DD HH:mm')) if v1 and v2
        FF.normalizeSingleOrArray values, form.entityMeta.fields[fieldName].multiple
}