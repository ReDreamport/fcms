FF = F.Form

# TODO 暂时只支持单选，multiple==true 暂不支持，可以选择使用 CheckList

FF.Select = {
    buildField: (form, fieldName, $fieldInputSlot, entityInitValue) ->
        fieldMeta = form.entityMeta.fields[fieldName]

        $item = $ FT.Select({field: fieldMeta, fClass: form.fClass})
        $fieldInputSlot.append($item)
        $select = $item.find('select:first')

        rebuildOptions = (options, selectedValue)=>
            if $select.children().length # 表示是重新构建，那么需要先取出当前选中的选项
                selectedValue = $select.find('option:first').val()

            $select.empty()

            return unless options
            for option in options when option.name != "----" # TODO 暂时无法显示分割线
                selected = option.name == selectedValue
                $('<option>').attr('value', option.name).html(option.label).prop('selected', selected).appendTo($select)

        FF.initSelectInput(rebuildOptions, fieldMeta, form, entityInitValue)

    getInput: (form, fieldName)->
        $field = FF.get$field(form, fieldName)
        values = []
        $field.find(".fw-field-item-input.#{form.fClass} option:selected").each -> values.push($(this).val())
        FF.normalizeSingleOrArray values, form.entityMeta.fields[fieldName].multiple
}