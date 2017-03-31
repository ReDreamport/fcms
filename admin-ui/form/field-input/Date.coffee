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
            $this = $(this)
            year = $this.find('.date-year:first').val()
            month = $this.find('.date-month:first').val()
            day = $this.find('.date-day:first').val()

            if year || month || day
                unless year && month && day # 要么不输入，要么全部输入
                    $this.find('.date-year:first').focus()
                    throw "时间输入有误"

                m = moment("#{year}-#{month}-#{day}", ["YYYY-M-D"], true)
                if m.isValid()
                    values.push(m.valueOf())
                else
                    $this.find('.date-year:first').focus()
                    throw "时间输入有误"
        FF.normalizeSingleOrArray values, form.entityMeta.fields[fieldName].multiple
}