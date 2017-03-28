F.initEntityGlobalEvent = ->
    $doc = $(document)
    $doc.on 'click', '.to-view-entity', (e)->
        $this = $(this)
        _id = $this.attr('_id')
        return unless _id
        F.toViewEntity($this.attr('entityName'), _id)

        e.preventDefault()
        e.stopPropagation()

    $doc.on 'click', '.to-update-entity', (e)->
        $this = $(this)
        F.toUpdateEntity($this.attr('entityName'), $this.attr('_id'))

        e.preventDefault()
        e.stopPropagation()

    $doc.on 'click', '.to-add-entity', (e)->
        $this = $(this)
        F.toUpdateEntity($this.attr('entityName'))

        e.preventDefault()
        e.stopPropagation()

    $doc.on 'click', '.to-list-entity', (e)->
        $this = $(this)
        F.toListEntity $this.attr('entityName')

        e.preventDefault()
        e.stopPropagation()

F.hasDigestFields = (entityMeta)->
    return entityMeta.digestFields?.length > 0

F.digestEntity = (entityMeta, entityValue)->
    return "" unless entityValue
    if entityMeta.digestFields
        groups = entityMeta.digestFields.split(",")
        digest = []
        for group in groups
            fields = group.split('|')
            df = null
            for field in fields
                v = entityValue[field]
                if v?
                    df = {field: field, value: v}
                    break
            digest.push df
        FT.EntityDigest({entityMeta, digest})
    else
        F.digestId(entityValue._id)

F.digestEntityById = (entityMeta, id, $parent)->
    q = F.api.get "entity/#{entityMeta.name}/#{id}"
    q.catch (x)-> $parent.html '?Fail ' + x.status
    q.then (entityValue)-> $parent.html F.digestEntity(entityMeta, entityValue)

F.loadDigestedEntities = ($area)->
    DigestedEntityLoadQueue = {}

    $area.find('.loading-ref').each ->
        $this = $ this
        $this.removeClass 'loading-ref'
        entityName = $this.attr('entityName')
        _id = $this.attr('_id')

        digestFields = F.meta.entities[entityName].digestFields
        return unless digestFields?.length > 0 and digestFields != '_id'

        theEntityQueue = F.setIfNone(DigestedEntityLoadQueue, entityName, [])
        theEntityQueue.push {_id, $ref: $this}

    for entityName, tasks of DigestedEntityLoadQueue
        doLoadDigestedEntity entityName, tasks
    DigestedEntityLoadQueue = {}

doLoadDigestedEntity = (entityName, tasks)->
    _ids = (task._id for task in tasks)
    _criteria = {field: '_id', operator: 'in', value: _ids}

    idTo$ref = {}
    for task in tasks
        idTo$ref[task._id] = task.$ref

    entityMeta = F.meta.entities[entityName]
    q = F.api.get "entity/#{entityName}?_digest=true&_pageSize=-1&_criteria=#{JSON.stringify(_criteria)}"
    q.then (r)->
        list = r.page
        eMap = {}
        eMap[e._id] = e for e in list
        for task in tasks
            entity = eMap[task._id]
            task.$ref.html F.digestEntity(entityMeta, entity) if entity

F.tdStyleOfField = (fm)->
    switch fm.type
        when "ObjectId", "Reference", "String", "Password"
            {width: '140px', 'text-align': 'center'}
        when "Boolean"
            {width: '30px', 'text-align': 'center'}
        when "Int", "Float"
            {width: '80px', 'text-align': 'right'}
        when "Date", "Time", "DateTime"
            {width: '160px', 'text-align': 'center'}
        when "Image", "File"
            {width: '90px', 'text-align': 'center'}
        else
            {width: '100px', 'text-align': 'center'}