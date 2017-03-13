FF = F.Form

FF.initSelectInput = (rebuildOptions, fieldMeta, form, entityInitValue)->
    if fieldMeta.optionsDependOnField
        FF.enableOptionsDependOnField(form, fieldMeta, rebuildOptions, entityInitValue)
    else
        options = if fieldMeta.options?.length
            fieldMeta.options
        else if fieldMeta.optionsFunc
            F.ofPropertyPath(window, fieldMeta.optionsFunc)?(fieldMeta.name, form)
        rebuildOptions(options, entityInitValue[fieldMeta.name])

FF.enableOptionsDependOnField = (form, fieldMeta, rebuildOptions, entityInitValue)->
    # 本字段可以是多值的，依赖的字段必须是单值的
    optionsDependOnField = fieldMeta.optionsDependOnField
    dependentFieldMeta = form.entityMeta.fields[optionsDependOnField]
    return unless dependentFieldMeta and not dependentFieldMeta.multiple

    getOptions = (fv)->
        if fieldMeta.groupedOptions?.length
            fieldMeta.groupedOptions[fv]
        else if fieldMeta.optionsFunc
            F.ofPropertyPath(window, fieldMeta.optionsFunc)?(fieldMeta.name, form, fv)

    FF.FieldInputChangeEventManager.on form.fid, optionsDependOnField, ->
        inputType = form.entityMeta.fields[optionsDependOnField]?.inputType
        return unless inputType
        fv = FF[inputType].getInput(form, optionsDependOnField)
        rebuildOptions(getOptions(fv))

    # 初始化
    dependentFieldValue = entityInitValue[optionsDependOnField]
    rebuildOptions(getOptions(dependentFieldValue), entityInitValue[fieldMeta.name])

FF.normalizeSingleOrArray = (values, multiple)->
    if multiple
        values
    else
        if values.length then values[0] else null

FF.toggleVisible = ($this, $target)->
    if $this.hasClass('fa-eye')
        $this.removeClass('fa-eye').addClass('fa-eye-slash')
        $target.hide()
    else
        $this.removeClass('fa-eye-slash').addClass('fa-eye')
        $target.show()

FF.buildNormalField = (form, fieldName, $fieldInputSlot, entityInitValue, buildFieldItem) ->
    fieldMeta = form.entityMeta.fields[fieldName]

    fieldInitValue = entityInitValue?[fieldName]
    fieldInitValue = if fieldMeta.multiple then fieldInitValue || [] else [fieldInitValue]

    dependOnField = fieldMeta.optionsDependOnField
    if dependOnField and fieldMeta.groupedOptions?.length
        dependentFieldValue = entityInitValue?[dependOnField]

    for itemValue in fieldInitValue
        $fieldInputSlot.append buildFieldItem(form, fieldMeta, itemValue, dependentFieldValue)
