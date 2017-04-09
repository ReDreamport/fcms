F.toListEntity = (entityName)->
    pageId = "list-entity-#{entityName}"
    entityMeta = F.meta.entities[entityName]
    title = "#{entityMeta.label} 列表"

    F.openOrAddPage pageId, title, 'F.toListEntity', [entityName], ($page)->
        $view = $(FT.ListEntity({entityName})).appendTo($page.find('.page-content'))

        build$table = (fieldNames)-> $ FT.ListEntityTable {fieldNames, entityMeta}
        build$tbody = (fieldNames, page) -> FT.ListEntityTbody {fieldNames, page, entityMeta}

        {$action, $table, $refreshPageBtn} = F.enableListEntity(entityMeta, $view, build$table, build$tbody, pageId)

        $table.on 'click', '.remove-entity', ->
            _id = $(this).attr("_id")
            q = F.api.remove "entity/#{entityName}?_ids=#{_id}"
            q.catch F.alertAjaxError
            q.then ->
                F.toastSuccess('删除成功')
                $refreshPageBtn.click()

        $view.find('.remove-entities:first').click ->
            ids = []
            $table.find('.select:checked').each ->
                $tr = $(this).closest('tr')
                ids.push $tr.attr('_id')
            return unless ids.length
            return unless confirm("确认要删除#{ids.length}个#{entityMeta.label}？")

            q = F.api.remove "entity/#{entityName}?_ids=" + ids.join(",")
            q.catch F.alertAjaxError
            q.then ->
                F.toastSuccess('删除成功')
                $refreshPageBtn.click()

F.enableListEntity = (entityMeta, $view, build$table, build$tbody, pageId, onPageRefresh)->
    $action = $(FT.EntityListPaging({entityName: entityMeta.name, entityMeta})).appendTo($view)

    fields = entityMeta.fields
    fieldNames = []
    columnsDisplay = {}
    for fn, fm of fields
        continue if fn == '_id' || fn == '_version' # 不含 _id、_version
        continue if fm.type == 'Password' || fm.hideInListPage
        continue if fm.notShow and not F.checkAclField(entityMeta.name, fn, 'show')

        fieldNames.push fn

    # 其他系统字段放最后
    for systemField in ['_createdOn', '_createdBy', '_modifiedOn', '_modifiedBy']
        if F.removeFromArray fieldNames, systemField
            fieldNames.push systemField

    columnsDisplay[name] = true for name in fieldNames

    $tableScroll = build$table(fieldNames).appendTo($view)
    $table = $tableScroll.find('table:first')

    displayColumns = ->
        tableWidth = 100 + 40 + 40
        for fieldName in fieldNames
            if columnsDisplay[fieldName]
                $table.find('.col-' + fieldName).show()
                tableWidth += FS.pxToNumber(F.tdStyleOfField(fields[fieldName]).width)
            else
                $table.find('.col-' + fieldName).hide()
        $table.width tableWidth + 'px'

    displayColumns()

    $pageNo = $action.find('.page-no')
    $pageSize = $action.find('.page-size')
    $refreshPageBtn = $action.find('.refresh-page')
    $filters = $action.find('.filters:first')
    $columnsDisplay = $action.find('.columns-display:first')

    $action.find('.prev-page').click ->
        pageNo = parseInt $pageNo.val(), 10
        pageSize = parseInt $pageSize.val(), 10
        pageNo--
        pageNo = 1 if pageNo < 1
        $pageNo.val(pageNo)
        loadEntityList(pageNo, pageSize)

    $action.find('.next-page').click ->
        pageNo = parseInt $pageNo.val(), 10
        pageSize = parseInt $pageSize.val(), 10
        pageNo++
        pageNo = 1 if pageNo < 1
        $pageNo.val(pageNo)
        loadEntityList(pageNo, pageSize)

    $refreshPageBtn.click ->
        pageNo = parseInt $pageNo.val(), 10
        pageSize = parseInt $pageSize.val(), 10
        pageNo = 1 if pageNo < 1
        $pageNo.val(pageNo)
        loadEntityList(pageNo, pageSize)

    $table.find('.toggle-check-all:first').click ->
        checked = $(this).prop('checked')
        $table.find('.select').prop('checked', checked)

    $action.find('.columns').click ->
        if $columnsDisplay.is(':visible')
            $columnsDisplay.hide()
        else
            $columnsDisplay.show()
            $columnsDisplay.find('.column-names').html FT.CheckColumns({fieldNames, columnsDisplay, fields})

    $action.find('.confirm-columns-display').click ->
        columnsDisplay = {}
        $columnsDisplay.find('input:checked').each ->
            columnsDisplay[$(this).val()] = true
        $columnsDisplay.hide()
        displayColumns()

    #====================================
    # 添加搜索条件
    #====================================

    $filtersAction = $action.find('.filters-action')

    addFilter = (field, operator, value)->
        $filter = $(FT.FilterItem({fields: entityMeta.fields})).appendTo($filters)
        $fieldName = $filter.find('.field-name:first')
        $operator = $('.operator:first', $filter)
        $filterInput = $filter.find('.filter-input:first')

        $fieldName.val field if field
        $operator.val operator if operator

        lastFieldName = null
        lastOperator = null

        $filter.find('.remove-item:first').click -> $filter.remove()

        fieldChanged = ->
            fieldName = $fieldName.val()
            return unless fieldName

            fieldMeta = entityMeta.fields[fieldName]
            operators = if fieldMeta.type == 'Boolean'
                if fieldMeta.multiple then [] else ["==", "!="]
            else if F.isFieldOfTypeDateOrTime(fieldMeta) || F.isFieldOfTypeNumber(fieldMeta)
                ["==", "!=", ">", ">=", "<", "<=", "in", "nin", "empty", "nempty"]
            else if fieldMeta.type == 'Reference'
                ["==", "!=", "in", "nin", "empty", "nempty"]
            else if fieldMeta.type == 'String'
                ["==", "!=", "in", "nin", "start", "end", "contain", "empty", "nempty"]
            else if fieldMeta.type == 'ObjectId'
                ["==", "!=", "in", "nin", "empty", "nempty"]

            operatorLabels = {
                "==": "等于", "!=": "不等于", ">": "大于", ">=": "大于等于", "<": "小于", "<=": "小于等于",
                "in": "等于以下值", "nin": "不等于以下值", "start": "开头", "end": "结尾", "contain": "包含",
                "empty": "空", "nempty": "非空"
            }

            operator = $operator.val()
            $operator.html(FT.FilterOperatorOption({operatorLabels, operators}))
            $operator.val(operator) if operator

            operatorChanged()

        operatorChanged = ->
            fieldName = $fieldName.val()
            operator = $operator.val()
            return unless fieldName and operator
            return if lastFieldName == fieldName and lastOperator == operator
            lastFieldName = fieldName
            lastOperator = operator

            fieldMeta = entityMeta.fields[fieldName]
            multiple = operator == "in" || operator == "nin"

            if operator == 'empty' || operator == 'nempty'
                $filterInput.empty()
            else if operator == "start" || operator == "end" || operator == "contain"
                $filterInput.html(FT.FilterInput({input: "String", multiple: false}))
            else if F.isFieldOfInputTypeOption(fieldMeta)
                $filterInput.html(FT.FilterInput({input: "Select", multiple: multiple, options: fieldMeta.options}))
            else if fieldMeta.type == 'Boolean'
                $filterInput.html(FT.FilterInput({input: "Boolean", multiple: false}))
            else if F.isFieldOfTypeDateOrTime(fieldMeta) || F.isFieldOfTypeNumber(fieldMeta)
                $filterInput.html(FT.FilterInput({input: fieldMeta.type, multiple: multiple}))
            else if fieldMeta.type == 'Reference'
                $filterInput.html(FT.FilterInput({
                    input: 'Reference',
                    multiple: multiple,
                    refEntity: fieldMeta.refEntity
                }))
            else if fieldMeta.type == 'String' || fieldMeta.type == 'ObjectId'
                $filterInput.html(FT.FilterInput({input: "String", multiple: multiple}))

            # 添加项
            $('.add-input-item:first', $filterInput).click ->
                $(this).next('.filter-input-item.hidden').clone().appendTo($filterInput).removeClass('hidden')
            $filterInput.on 'click', '.remove-input-item', ->
                operator = $operator.val()
                $ii = $(this).closest('.filter-input-item')
                if $ii.attr('input') == 'Reference' and (operator != 'in' && operator != 'nin')
                    $ii.find('.ref-holder').remove()
                    $ii.attr('_id', '')
                else
                    $ii.remove()

            # 修改关联实体
            $('.edit-refs:first', $filterInput).click ->
                multipleOptions = {multiple: multiple, multipleUnique: true}
                selectedEntityIds = []
                $filterInput.find('.filter-input-item:visible').each -> selectedEntityIds.push $(this).attr('_id')
                refEntityMeta = F.meta.entities[fieldMeta.refEntity]
                F.toSelectEntity fieldMeta.refEntity, multipleOptions, selectedEntityIds, (idOrIds)->
                    if multiple
                        for id in idOrIds
                            $ii = $filterInput.find('.filter-input-item.hidden').clone().appendTo($filterInput)
                                .removeClass('hidden').attr('_id', id)
                            $holder = $ii.find('.ref-holder:first').empty()
                            $holder.attr '_id', id
                            F.digestEntityById refEntityMeta, id, $holder
                    else
                        $ii = $filterInput.find('.filter-input-item:first').attr('_id', idOrIds)
                        $holder = $ii.find('.ref-holder:first').empty()
                        $holder.attr '_id', idOrIds
                        F.digestEntityById refEntityMeta, idOrIds, $holder

        $fieldName.change fieldChanged
        $operator.change operatorChanged

        fieldChanged()

    $('.more-search:first', $action).click -> $filters.toggle()

    $('.add-filter:first', $action).click -> addFilter null, null

    $('.clear-filters:first', $action).click -> $action.find('.filter-item').remove()

    $('.save-filters:first', $action).click ->
        criteria = getListCriteria(true)
        criteria = JSON.stringify(criteria)
        sortBy = $action.find('.sort-field:first').val()
        sortOrder = $action.find('.sort-order:first').val()

        name = $.trim $action.find('.filters-name:first').val()
        unless name
            F.toastWarning("请输入一个查询名称")
            return

        q = F.api.put "entity/filters", {name, entityName: entityMeta.name, criteria, sortBy, sortOrder}
        q.catch F.alertAjaxError
        q.then ->
            refreshFiltersList()
            F.toastSuccess('保存成功')

    $('.remove-filters', $action).click ->
        name = $.trim $action.find('.filters-name:first').val()
        unless name
            F.toastWarning("请输入一个查询名称")
            return

        q = F.api.remove "entity/filters?entityName=#{entityName}&name=#{name}"
        q.catch F.alertAjaxError
        q.then ->
            refreshFiltersList()
            F.toastSuccess('删除成功')

    $filtersAction.on 'click', '.pre-filters', ->
        _id = $(this).attr('_id')
        for f in filtersList
            if f._id == _id
                $action.find('.filters-name:first').val(f.name)
                $action.find('.sort-field:first').val(f.sortBy)
                $action.find('.sort-order:first').val(f.sortOrder)

                $filters.find('.filter-item').remove()
                criteria = JSON.parse f.criteria
                criteria = criteria.items || []
                for c in criteria
                    addFilter(c.field, c.operator, c.value)
                break

    filtersList = null
    refreshFiltersList = ->
        query = {pageSize: -1, _criteria: JSON.stringify({entityName: entityMeta.name})}
        listFiltersQ = F.api.get 'entity/F_ListFilters', query
        listFiltersQ.then (fl)->
            filtersList = fl.page
            $filtersAction.find('.pre-filters').remove()
            for f in filtersList
                FS.$LinkButton().addClass("pre-filters plain-btn")
                    .html(f.name).attr('_id': f._id).appendTo($filtersAction)
    refreshFiltersList()

    #====================================
    # 获取搜索条件
    #====================================
    getListCriteria = (keepEmptyFilter)->
        criteria = []
        $filters.find('.filter-item').each ->
            $item = $ this
            fieldName = $item.find('.field-name:first').val()
            operator = $item.find('.operator:first').val()
            return unless fieldName and operator
            values = []
            $item.find('.filter-input .filter-input-item:visible').each ->
                $ii = $ this
                inputType = $ii.attr('input')
                value = if inputType == 'Reference'
                    $ii.find('.ref-holder:first').attr('_id')
                else if inputType == 'Boolean'
                    b = $ii.find('.input:checked').val()
                    if b == 'false'
                        operator = operator == '==' && '!=' || '=='
                        true
                    else b
                else if inputType == 'DateTime'
                    v1 = $ii.find('.input-date').val()
                    v2 = $ii.find('.input-time').val()
                    F.dateStringToInt(v1 + " " + v2, 'YYYY-MM-DD HH:mm')
                else if inputType == 'Date'
                    v = $ii.find('.input')
                    F.dateStringToInt(v, 'YYYY-MM-DD')
                else if inputType == 'Date'
                    v = $ii.find('.input')
                    F.dateStringToInt(v, 'HH:mm')
                else
                    $ii.find('.input').val()
                values.push value if value
            if values.length || keepEmptyFilter
                values = if operator == 'in' || operator == 'nin' then values else values[0]
                criteria.push {field: fieldName, operator: operator, value: values}
        console.log criteria
        if criteria.length
            {relation: 'and', items: criteria}
        else
            {}

    loadEntityList = (pageNo, pageSize)->
        query = {_pageNo: pageNo, _pageSize: pageSize}

        _filter = $.trim $action.find('.fast-search').val()
        if _filter
            query._filter = _filter
        else
            criteria = getListCriteria()
            query._criteria = JSON.stringify(criteria) if F.objectSize(criteria)

        query._sortBy = $action.find('.sort-field:first').val()
        query._sortOrder = $action.find('.sort-order:first').val()

        q = F.api.get "entity/" + entityMeta.name, query
        q.catch (jqxhr)->
            F.removePage(pageId) if pageId # 加载失败移除页面
            F.alertAjaxError jqxhr
        q.then (r)->
            $view.find('.total').html r.total
            pageNum = Math.ceil(r.total / pageSize)
            $view.find('.page-num').html pageNum

            if r.total > 0 and pageNo > pageNum
                $pageNo.val(pageNum)
                loadEntityList(pageNum, pageSize)
                return

            $table.find('tbody').remove()
            $table.append build$tbody(fieldNames, r.page)
            F.loadDigestedEntities($table)
            onPageRefresh?()

    $refreshPageBtn.click()

    {$action, $table, $refreshPageBtn}



