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
            $this = $(this)
            hour = $this.find('.date-hour:first').val()
            minute = $this.find('.date-minute:first').val()

            if hour || minute
                unless hour && minute # 要么不输入，要么全部输入
                    $this.find('.date-hour:first').focus()
                    throw "时间输入有误"

                m = moment("#{hour}:#{minute}", ["H:m"], true)
                if m.isValid()
                    values.push(m.valueOf())
                else
                    $this.find('.date-hour:first').focus()
                    throw "时间输入有误"
        FF.normalizeSingleOrArray values, form.entityMeta.fields[fieldName].multiple
}