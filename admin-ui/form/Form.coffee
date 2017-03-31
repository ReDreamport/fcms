FF = F.Form
GLOBAL_FORM_ID = 0

FF.buildRootForm = (entityName, entityInitValue)->
    form = FF.buildForm(entityName, entityInitValue)
    form.$form.attr('_version', entityInitValue?._version)

    # =======================================
    # 仅在最上层表单上绑定，嵌套表单（子组件）不要绑定，否则就重复了！！！
    $form = form.$form

    # 隐藏字段的所有项
    $form.on 'click', '.fw-field-hide-items', (e)->
        $this = $(this)
        if $this.hasClass('fa-eye')
            $this.removeClass('fa-eye').addClass('fa-eye-slash')
            $this.closest('.fw-field').find(".fw-field-input:first>.fw-field-item").hide()
        else
            $this.removeClass('fa-eye-slash').addClass('fa-eye')
            $this.closest('.fw-field').find(".fw-field-input:first>.fw-field-item").show()

        e.stopPropagation()
        e.preventDefault()
        false

    # 字段添加一项
    $form.on 'click', '.fw-field-add-item', (e)->
        $field = $(this).closest('.fw-field')
        fieldName = $field.attr('name')

        $form = $field.closest('.form')
        form = FF.$formToForm($form)
        entityName = $form.attr('entityName')
        entityMeta = F.meta.entities[entityName]
        fieldMeta = entityMeta.fields[fieldName]

        $fieldInputSlot = $field.find(".fw-field-input:first")

        $fieldInputSlot.append F.Form[fieldMeta.inputType].buildFieldItem form, fieldMeta, null

        e.stopPropagation()
        e.preventDefault()
        false

    # 字段移除一项
    $form.on 'click', '.fw-field-remove-item', (e)->
        $item = $(this).closest('.fw-field-item')
        $item.find('.form').each -> FF.disposeForm(FF.$formToForm($(this)))
        $item.remove()

        e.stopPropagation()
        e.preventDefault()
        false

    # 移除字段的所有项
    $form.on 'click', '.fw-field-remove-all-items', (e)->
        $items = $(this).closest('.fw-field').find(">.fw-field-item")
        $items.each ->
            $(this).find('.form').each -> FF.disposeForm(FF.$formToForm($(this)))
        $items.remove()

        e.stopPropagation()
        e.preventDefault()
        false

    # 监测输入修改
    $form.on 'change', 'input, select, textarea', (e)->
        $this = $ this
        fieldName = $this.closest('.fw-field').attr('name')
        fid = $this.closest('.form').attr('fid')

        FieldInputChangeEventManager.fire fid, fieldName

    # 最后返回 form
    form

FF.buildForm = (entityName, entityInitValue)->
    entityMeta = F.meta.entities[entityName]
    fid = GLOBAL_FORM_ID++ # form id
    fClass = "fid-#{fid}" # form mark class

    isCreate = not entityInitValue?._id?

    $form = $ FT.Form({entityName, fid, isCreate})

    form = {entityName, entityMeta, fid, fClass, $form, isCreate}

    form.rebuildInput = (entityValue)->
        $formInput = $('.form-input:first', $form).empty()
        fields = entityMeta.fields
        for fieldName, fieldMeta of fields
            continue if fieldMeta.notShow
            if isCreate
                continue if fieldMeta.noCreate and not F.checkAclField(entityMeta.name, fieldName, 'create')
            else
                continue if fieldMeta.noEdit and not F.checkAclField(entityMeta.name, fieldName, 'edit')

            fieldClass = "fn-#{fieldName} #{fClass} ftype-#{fieldMeta.type} finput-#{fieldMeta.inputType}"
            fieldClass += " of-multiple" if fieldMeta.multiple
            $field = $ FT.Field({field: fieldMeta, fieldClass, fClass})
            $field.appendTo($formInput)
            $fieldInputSlot = $('.fw-field-input', $field)

            if fieldMeta.inputFunc
                inputFunc = F.ofPropertyPath window, fieldMeta.inputFunc
                inputFunc.buildField form, fieldName, $fieldInputSlot, entityValue
            else
                inputType = F.Form[fieldMeta.inputType]
                console.log("Not found input type " + fieldMeta.inputType + ", fieldName: " + fieldName) unless inputType
                inputType?.buildField form, fieldName, $fieldInputSlot, entityValue

                # 排序使能
                if fieldMeta.multiple
                    # FS.sortable({$container: $field, sortableNodeSelector: '.fw-field-item'})
                    $field.sortable({items: '.fw-field-item'})

    form.rebuildInput entityInitValue

    # ==========================
    # 事件
    $formEditor = $('.form-editor:first', $form)
    $fInput = $('>.form-input', $formEditor) # 必须通过 $formEditor 限定
    $fJson = $('>.form-json', $formEditor)

    $form.find('.toggle-form-visible:first').on 'click', (e)-> # 整个表单的显隐切换
        $this = $(this)
        if $this.hasClass('fa-plus-square') # 应展开
            $this.removeClass('fa-plus-square').addClass('fa-minus-square')
            $formEditor.show()
        else # 应折叠
            $this.removeClass('fa-minus-square').addClass('fa-plus-square')
            $formEditor.hide()

        e.stopPropagation()
        e.preventDefault()
        false

    $form.find('.show-editor-input:first').click (e)->
        $fInput.show()
        $fJson.hide()
        e.stopPropagation()
        e.preventDefault()
        false

    $form.find('.show-editor-json:first').click (e)->
        $fInput.hide()
        $fJson.show()

        json = {}
        try
            FF.collectFormInput form, json
        catch e
            F.toastError(e)
            return

        $fJson.find('textarea:first').val(JSON.stringify(json, null, 4))

        e.stopPropagation()
        e.preventDefault()
        false

    $fJson.find('.json-to-input:first').click ->
        json = $fJson.find('textarea:first').val()
        try
            json = json && JSON.parse(json)
        catch
            F.toastError('JSON 格式有误')
            return

        form.rebuildInput json

        $fInput.show()
        $fJson.hide()


    F.ofPropertyPath(window, entityMeta.editEnhanceFunc)?(entityMeta, form) if entityMeta.editEnhanceFunc

    # ==========================
    # 返回 form
    form

FF.$formToForm = ($form)->
    entityName = $form.attr('entityName')
    fid = $form.attr('fid')
    fClass = "fid-#{fid}"
    entityMeta = F.meta.entities[entityName]

    {entityName, entityMeta, fid, fClass, $form}

FF.get$field = (form, fieldName)-> form.$form.find(".fn-#{fieldName}.#{form.fClass}")

FF.collectFieldInput = (form, fieldMeta)->
    if fieldMeta.inputFunc
        inputFunc = F.ofPropertyPath window, fieldMeta.inputFunc
        inputFunc.getInput(form, fieldMeta.name)
    else
        FF[fieldMeta.inputType].getInput(form, fieldMeta.name)

# 收集界面上输入的实体的值
FF.collectFormInput = (form, formValue, isCreate)->
    fields = form.entityMeta.fields
    for fieldName, fieldMeta of fields
        continue if fieldMeta.notShow
        if isCreate
            continue if fieldMeta.noCreate and not F.checkAclField(form.entityMeta.name, fieldName, 'create')
        else
            continue if fieldMeta.noEdit and not F.checkAclField(form.entityMeta.name, fieldName, 'edit')

        fv = FF.collectFieldInput form, fieldMeta
        formValue[fieldName] = fv if fv != undefined
    # 取此表单的版本号
    _version = form.$form.attr('_version')
    _version = F.stringToInt _version, null
    formValue._version = _version if _version?

FF.disposeForm = (form)->
    FieldInputChangeEventManager.off(form.fid)
    form.$form.find('.form').each -> FieldInputChangeEventManager.off($(this).attr('fid'))

FieldInputChangeEventManager =
    getListeners: (fid, fieldName)->
        @listeners = @listeners || {}
        @listeners[fid] = @listeners[fid] || {}
        @listeners[fid][fieldName] = @listeners[fid][fieldName] || []
    fire: (fid, fieldName)->
        listeners = @getListeners(fid, fieldName)
        for l in listeners
            l(fid, fieldName)
    on: (fid, fieldName, listener)->
        listeners = @getListeners(fid, fieldName)
        listeners.push listener
    off: (fid)->
        return unless @listeners
        delete @listeners[fid]

FF.FieldInputChangeEventManager = FieldInputChangeEventManager