FF = F.Form

upload = ($file, entityName, fieldName, $status, callback)->
    $status.html "上传中..."
    F.api.upload $file, entityName, fieldName, (result, data)->
        $status.html ""
        callback data if result

FF.buildFileOrImageField = (inputTemplate, itemTemplate)->
    (form, fieldName, $fieldInputSlot, entityInitValue) ->
        $field = $fieldInputSlot.closest('.fw-field')
        fieldMeta = form.entityMeta.fields[fieldName]
        $upload = $ inputTemplate({field: fieldMeta})
        $upload.appendTo($fieldInputSlot)
        $file = $field.find('input.file:first')
        $status = $upload.find('.status:first')
        # $field.find('.select-file:first').click -> $file.click()
        $file.on 'change', ->
            upload $file, form.entityName, fieldName, $status, (fileInfo)->
                $upload.find('.fw-field-item').remove() if !fieldMeta.multiple
                $upload.append itemTemplate({file: fileInfo, fClass: form.fClass})
            $file.val("") # 以允许选择相同的文件上传

        # 初始值
        fieldValue = entityInitValue[fieldName]
        if fieldMeta.multiple and fieldValue
            for file in fieldValue
                $upload.append itemTemplate({file, fClass: form.fClass})
        else if fieldValue
            $upload.append itemTemplate({file: fieldValue, fClass: form.fClass})

        $field.on 'click', '.fw-remove-file', (e)-> # 多值，删除一项
            $item = $(this).closest('.fw-field-item')
            $item.remove()
            e.stopPropagation()
            e.preventDefault()
            false

        $field.on 'click', '.fw-remove-all-file', (e)-> # 多值，删除所有项
            $upload.find('.fw-field-item').remove()
            e.stopPropagation()
            e.preventDefault()
            false

        $field.on 'click', '.fw-hide-all-file', (e)->
            FF.toggleVisible($(this), $upload.find('.fw-field-item'))

            e.stopPropagation()
            e.preventDefault()
            false

FF.File = {
    buildField: FF.buildFileOrImageField(FT.File, FT.FileItem)

    getInput: (form, fieldName)->
        $field = FF.get$field(form, fieldName)
        values = []
        $field.find(".fw-field-item.#{form.fClass}").each -> values.push JSON.parse($(this).attr('file'))
        FF.normalizeSingleOrArray values, form.entityMeta.fields[fieldName].multiple
}