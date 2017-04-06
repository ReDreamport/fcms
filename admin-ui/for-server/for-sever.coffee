stringArrayToOptionArray = (stringArr)->
    return {} unless stringArr
    ({name: str, label: str} for str in stringArr)

F.optionsOfInputType = (fieldName, form, dependentValue)->
    options = switch dependentValue
        when "ObjectId" then []
        when "String" then ["Text", "TextArea", "RichText", "Select", "CheckList"]
        when "Password" then ["Password"]
        when "Boolean" then ["Check", "Select"]
        when "Int" then ["Int", "Select"]
        when "Float" then ["Float", "Select"]
        when "Date" then ["Date", "Select"]
        when "Time" then ["Time", "Select"]
        when "DateTime" then ["DateTime", "Select"]
        when "Image" then ["Image"]
        when "File" then ["File"]
        when "Component" then ["InlineComponent", "PopupComponent", "TabledComponent"]
        when "Reference" then ["Reference"]
    stringArrayToOptionArray options

F.optionsOfPersistType = (fieldName, form, dependentValue)->
    options = switch dependentValue
        when "ObjectId" then ["ObjectId", "String", "varchar", "char"]
        when "String" then ["String", "varchar", "char", "blob", "text"]
        when "Password" then ["String", "varchar", "char"]
        when "Boolean" then ["Boolean", "varchar", "char", "int", "bit", "tinyint"]
        when "Int" then ["Number", "int", "bit", "tinyint", "bigint"]
        when "Float" then ["Number", "decimal", "float", "double"]
        when "Date" then ["Date", "date"]
        when "Time" then ["Date", "time"]
        when "DateTime" then ["Date", "datetime", "timestamp"]
        when "Image" then ["String", "varchar"]
        when "File" then ["String", "varchar"]
        when "Component" then ['Document']
        when "Reference" then ["ObjectId", "String", "varchar", "char"]
        when "Object" then ['Document']
    stringArrayToOptionArray options

F.optionsOfEntityPermissions = (fieldName, form, dependentValue)->
    options = []
    options.push {
        name: 'all',
        items: stringArrayToOptionArray(["*/*", "ListEntity/*", "GetOneEntity/*", "CreateEntity/*", "UpdateOneEntity/*",
            "UpdateManyEntity/*",
            "DeleteManyEntity/*", "RecoverManyEntity/*"])
    }

    entities = F.meta.entities
    for eName of entities
        items = []
        items.push "*/" + eName
        items.push "ListEntity/" + eName
        items.push "GetOneEntity/" + eName
        items.push "CreateEntity/" + eName
        items.push "UpdateOneEntity/" + eName
        items.push "UpdateManyEntity/" + eName
        items.push "DeleteManyEntity/" + eName
        items.push "RecoverManyEntity/" + eName
        options.push {name: eName, items: stringArrayToOptionArray(items)}

    options

F.optionsOfEntityPermissions = (fieldName, form, dependentValue)->
    options = []
    options.push {
        name: 'all',
        items: stringArrayToOptionArray(["*/*", "ListEntity/*", "GetOneEntity/*", "CreateEntity/*", "UpdateOneEntity/*",
            "UpdateManyEntity/*", "DeleteManyEntity/*", "RecoverManyEntity/*"])
    }
    entities = F.meta.entities
    for eName of entities
        items = []
        items.push "*/" + eName
        items.push "ListEntity/" + eName
        items.push "GetOneEntity/" + eName
        items.push "CreateEntity/" + eName
        items.push "UpdateOneEntity/" + eName
        items.push "UpdateManyEntity/" + eName
        items.push "DeleteManyEntity/" + eName
        items.push "RecoverManyEntity/" + eName
        options.push {name: eName, items: stringArrayToOptionArray(items)}

    options

F.optionsOfMenuPermissions = (fieldName, form, dependentValue)->
    options = []
    entities = F.meta.entities
    menuGroups = F.menuData.menuGroups || []
    for menuGroup in menuGroups
        menuItems = menuGroup.menuItems
        for menuItem in menuItems
            options.push menuItem.callFunc if menuItem.callFunc

    stringArrayToOptionArray(options)

F.optionsOfEntitiesFields = ->
    options = []
    entities = F.meta.entities
    for entityName, em of entities
        items = []
        for fieldName,fm of em.fields
            items.push {label: fm.label, name: "#{entityName}/#{fieldName}"}
        options.push {name: em.label, items}
    options

F.enhanceFieldMetaEdit = (entityMeta, form)->
    $form = form.$form
    $fieldRefEntity = $form.find('.fw-field.fn-refEntity')
    $fieldMultipleUnique = $form.find('.fw-field.fn-multipleUnique')
    $fieldMultipleMin = $form.find('.fw-field.fn-multipleMin')
    $fieldMultipleMax = $form.find('.fw-field.fn-multipleMax')

    $fieldOptions = $form.find('.fw-field.fn-options')
    $fieldOptionsDependOnField = $form.find('.fw-field.fn-optionsDependOnField')
    $fieldOptionsFunc = $form.find('.fw-field.fn-optionsFunc')
    $fieldGroupedOptions = $form.find('.fw-field.fn-groupedOptions')
    $fieldOptionWidth = $form.find('.fw-field.fn-optionWidth')

    $fieldFileStoreDir = $form.find('.fw-field.fn-fileStoreDir')
    $fieldRemovePreviousFile = $form.find('.fw-field.fn-removePreviousFile')

    visibleDisplay = 'inline-block'

    onTypeChange = ->
        type = F.Form.Select.getInput(form, 'type')
        FS.setDisplay $fieldRefEntity, (type == 'Reference' || type == 'Component'), visibleDisplay

        v = type == 'Image' || type == 'File'
        FS.setDisplay $fieldFileStoreDir, v, visibleDisplay
        FS.setDisplay $fieldRemovePreviousFile, v, visibleDisplay

    onMultipleChange = ->
        v = F.Form.Check.getInput(form, 'multiple')
        FS.setDisplay $fieldMultipleUnique, v, visibleDisplay
        FS.setDisplay $fieldMultipleMin, v, visibleDisplay
        FS.setDisplay $fieldMultipleMax, v, visibleDisplay

    onInputTypeChange = ->
        inputType = F.Form.Select.getInput(form, 'inputType')
        v = inputType == 'Select'
        FS.setDisplay $fieldOptions, v, visibleDisplay
        FS.setDisplay $fieldOptionsDependOnField, v, visibleDisplay
        FS.setDisplay $fieldOptionsFunc, v, visibleDisplay
        FS.setDisplay $fieldGroupedOptions, v, visibleDisplay
        FS.setDisplay $fieldOptionWidth, v, visibleDisplay

    F.Form.FieldInputChangeEventManager.on form.fid, 'type', onTypeChange
    F.Form.FieldInputChangeEventManager.on form.fid, 'multiple', onMultipleChange

    onTypeChange()
    onMultipleChange()
    onInputTypeChange()

F.emptyFunction = -> false

F.inputACL = {
    buildField: (form, fieldName, $fieldInputSlot, entityInitValue) ->
        aclValue = entityInitValue[fieldName] || {}
        q = F.api.get 'meta/actions'
        q.catch F.alertAjaxError
        q.then (actions)->
            $fieldInputSlot.append FT.InputACL({aclValue, menuGroups: F.menuData.menuGroups, actions})
            $fieldInputSlot.find('[name="section"]').click ->
                $fieldInputSlot.find('.acl-section').hide()
                $fieldInputSlot.find('.acl-section.' + $(this).val()).show()

            $selectEntityToFields = $fieldInputSlot.find('.select-entity-to-fields:first')
            $selectEntityToFields.change ->
                $fieldInputSlot.find('.acl-field-entity').hide()
                $fieldInputSlot.find('.acl-field-entity.acl-field-' + $selectEntityToFields.val()).show()

            $fieldInputSlot.find('.check-all').click ->
                $this = $ this
                checked = $this.prop('checked')
                $this.closest('.acl-section').find('input.right').prop('checked', checked)

            $fieldInputSlot.find('.check-column').click ->
                $this = $ this
                checked = $this.prop('checked')
                index = $this.attr('index')
                $this.closest('table').find("tbody tr td:nth-child(#{index}) input").prop('checked', checked)

    getInput: (form, fieldName)->
        $field = F.Form.get$field(form, fieldName)

        acl = {}

        acl.menu = []
        $field.find('.acl-menu:first input.right:checked').each ->
            acl.menu.push $(this).val()

        acl.action = []
        $field.find('.acl-action:first input.right:checked').each ->
            acl.action.push $(this).val()

        acl.entity = {}
        $field.find('.acl-entity:first tbody tr').each ->
            $tr = $ this
            entityName = $tr.attr 'entityName'
            rights = []
            $tr.find('input:checked').each ->
                rights.push $(this).val()
            acl.entity[entityName] = rights if rights.length

        acl.field = {}
        $field.find('.acl-field-entity').each ->
            $entity = $ this
            entity = {}
            $entity.find('tbody tr').each ->
                $tr = $ this
                field = []
                $tr.find('input:checked').each ->
                    field.push $(this).val()
                entity[$tr.attr('fieldName')] = field if field.length
            acl.field[$entity.attr('entityName')] = entity if F.objectSize(entity)

        acl
}