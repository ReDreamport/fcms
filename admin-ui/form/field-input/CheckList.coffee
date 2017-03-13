FF = F.Form

FF.CheckList = {
    buildField: (form, fieldName, $fieldInputSlot, entityInitValue) ->
        fieldMeta = form.entityMeta.fields[fieldName]

        $fi = $ FT.CheckList({field: fieldMeta})
        $fi.appendTo($fieldInputSlot)
        $list = $fi.find('.list:first')

        $fi.find('.toggle-check-all:first').click ->
            checked = $(this).prop('checked')
            $list.find(".fw-field-item.#{form.fClass}").prop('checked', checked)

        $fi.find('.fw-field-hide-options').click (e)->
            $this = $(this)
            if $this.hasClass('fa-eye')
                $this.removeClass('fa-eye').addClass('fa-eye-slash')
                $list.hide()
            else
                $this.removeClass('fa-eye-slash').addClass('fa-eye')
                $list.show()

            e.stopPropagation()
            e.preventDefault()

        rebuildOptions = (options, selectedValue)=>
            if $list.children().length # 表示是重新构建，那么需要先取出当前选中的选项
                selectedValue = @getInput(form, fieldName)
            selectedValue = selectedValue || []

            inputElementType = fieldMeta.multiple && 'checkbox' || 'radio'

            $list.empty()

            return unless options

            optionWidth = fieldMeta.optionWidth || 'auto'

            renderItem = (option, $parent)->
                checked = F.equalOrContainInArray(option.name, selectedValue)
                inputName = form.fClass + fieldMeta.name
                o = {
                    inputElementType, inputValue: option.name, checked, inputClass: form.fClass,
                    inputName, field: fieldMeta, optionLabel: option.label, optionWidth
                }
                $parent.append(FT.CheckListItem(o))

            for option in options # 只能两层
                if option.items
                    $group = $ FT.CheckListGroup(option)
                    $group.appendTo($list)
                    renderItem(item, $group) for item in option.items
                else
                    renderItem(option, $list)

        FF.initSelectInput(rebuildOptions, fieldMeta, form, entityInitValue)

    getInput: (form, fieldName)->
        $field = FF.get$field(form, fieldName)
        values = []
        $field.find(".fw-field-item.#{form.fClass}:checked").each -> values.push($(this).val())
        FF.normalizeSingleOrArray values, form.entityMeta.fields[fieldName].multiple
}


