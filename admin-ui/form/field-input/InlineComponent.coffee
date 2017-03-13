FF = F.Form

FF.InlineComponent = {
    buildField: (form, fieldName, $fieldInputSlot, entityInitValue) ->
        FF.buildNormalField(form, fieldName, $fieldInputSlot, entityInitValue, FF.InlineComponent.buildFieldItem)

    buildFieldItem: (form, fieldMeta, itemValue)->
        $item = $ FT.InlineComponent({field: fieldMeta, fClass: form.fClass})
        form = FF.buildForm(fieldMeta.refEntity, itemValue)
        $item.find('.fw-field-item-input:first').append form.$form
        $item

    getInput: (form, fieldName)->
        $field = FF.get$field(form, fieldName)
        values = []
        $form = $field.find(".fw-field-item-input.#{form.fClass} >.form")
        $form.each ->
            comValue = {}
            subForm = FF.$formToForm($(this))
            FF.collectFormInput(subForm, comValue)
            values.push comValue
        FF.normalizeSingleOrArray values, form.entityMeta.fields[fieldName].multiple
}