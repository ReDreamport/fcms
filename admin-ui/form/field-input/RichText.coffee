FF = F.Form

FF.RichText = {
    buildField: (form, fieldName, $fieldInputSlot, entityInitValue) ->
        FF.buildNormalField(form, fieldName, $fieldInputSlot, entityInitValue, FF.RichText.buildFieldItem)

        $fieldInputSlot.find('.fw-field-item-input').each ->
            editor = new wangEditor(this)

            editor.config.menus = [
                'fullscreen', 'source', 'undo', 'redo',
                '|', 'bold', 'underline', 'italic', 'strikethrough', 'forecolor', 'bgcolor', 'fontsize',
                'head', 'unorderlist', 'orderlist', 'alignleft', 'aligncenter', 'alignright',
                '|', 'link', 'unlink', 'table', 'emotion', 'img'
            ];
            editor.config.uploadImgUrl = F.apiRoot + "rich-text-file"
            editor.config.uploadImgFileName = "f0"

            editor.create()

    buildFieldItem: (form, fieldMeta, itemValue)->
        FT.RichText({field: fieldMeta, fClass: form.fClass, value: itemValue})

    getInput: (form, fieldName)->
        $field = FF.get$field(form, fieldName)
        values = []
        $field.find(".fw-field-item-input.#{form.fClass}").each -> values.push($(this).val())
        FF.normalizeSingleOrArray values, form.entityMeta.fields[fieldName].multiple
}