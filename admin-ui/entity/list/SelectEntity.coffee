F.toSelectEntity = (entityName, multipleOption, selectedEntityIds, callback)->
    {multiple, multipleUnique, multipleMin, multipleMax} = multipleOption

    entityMeta = F.meta.entities[entityName]

    $view = $(FT.SelectEntity({multiple}))

    win = F.openModalDialog({modal: true, content: $view, title: "选择 #{entityMeta.label}"})

    build$table = (fieldNames)-> $ FT.SelectEntityTable {multiple, fieldNames, entityMeta}
    build$tbody = (fieldNames, page) -> FT.SelectEntityTbody {multiple, selectedEntityIds, fieldNames, page, entityMeta}

    onPageRefresh = ->
        if multiple
            $table.find('tbody tr').each ->
                $this = $(this)
                _id = $this.attr('_id')
                if (_id in selectedEntityIds) or newSelectedIds[_id]
                    $this.find('.select:first').prop('checked', true)

    {$action, $table, $refreshPageBtn} = F.enableListEntity(entityMeta, $view, build$table, build$tbody, null, onPageRefresh)

    $table.addClass('hl-row')

    if multiple
        newSelectedIds = {}

        $table.on 'click', 'tbody tr', ->
            _id = $(this).attr("_id")
            newSelectedIds[_id] = true
            $(this).find('.select:first').prop('checked', true)

        $table.on 'click', '.select', (e)->
            $this = $(this)
            checked = $this.prop('checked')
            _id = $this.closest('tr').attr("_id")
            newSelectedIds[_id] = checked

            e.stopPropagation()

        $table.on 'click', '.toggle-check-all:first', ->
            checked = $(this).prop('checked')
            $table.find('tbody tr').each -> newSelectedIds[$(this).attr('_id')] = checked

        $view.find('.confirm:first').click ->
            win.close()
            ids = (_id for _id, v of newSelectedIds when v)
            callback ids

    else
        $table.on 'click', 'tbody tr', ->
            _id = $(this).attr("_id")
            win.close()
            callback _id


