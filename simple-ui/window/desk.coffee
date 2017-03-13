class Desk
    constructor: (options)->
        @windows = {}

        @node = FS.buildNode(classString: "fw-desk", parent: options.parent)

        @taskBarNode = FS.buildNode(classString: "fw-desk-task", parent: @node)

        @taskBarLeftAreaNode = FS.buildNode({
            classString: "fw-desk-task-left", parent: @taskBarNode,
            content: options.barLeft
        })

        @taskBarCenterAreaNode = FS.buildNode(classString: "fw-desk-task-center", parent: @taskBarNode)

        @taskBarRightAreaNode = FS.buildNode({
            classString: "fw-desk-task-right", parent: @taskBarNode,
            content: options.barRight
        })

        @deskNode = FS.buildNode(classString: "fw-desk-content", parent: @node)

        @windowZ = 1

    get: (id)->
        @windows[id]

    add: (id, options, func, args...)->
        options.parent = @deskNode
        options.modal = false
        options.movable = true
        options.resizable = true
        options.maximizable = true
        title = options.title

        win = new FS.Window(options)
        win.windowNode.setAttribute('pageId', id)

        barButtonNode = FS.buildLinkButton {
            classString: "fw-bar-button", parent: @taskBarCenterAreaNode, content: title
        }
        win.deskBarButtonNode = barButtonNode
        barButtonNode.addEventListener 'click', (e)=>
            @open(id)
            e.stopPropagation()
            e.preventDefault()

        @windows[id] = {window: win, button: barButtonNode, func, args}

        @layoutBar()

        win.on 'AfterClosed', => @removeWindowButton(id)
        win.on 'ToFront', => @onWindowToFront(id)

        @persistWindows()

        @open id

        win

    onWindowToFront: (id)->
        win = @windows[id]
        return unless win

        @taskBarCenterAreaNode.querySelector('.front')?.classList.remove('front')
        win.button.classList.add('front')
        @persistWindowSort()

    open: (id)->
        win = @windows[id]
        return false unless win

        @frontId = id
        win.window.toFront()

        win.window

    removeWindowButton: (id)->
        # 窗口已移除
        win = @windows[id]
        return unless win

        delete @windows[id]

        @taskBarCenterAreaNode.removeChild(win.button)
        @layoutBar()

        if @frontId == id
            maxZ = 0
            nextWinId = null
            for id, w of @windows
                z = getComputedStyle(w.window.windowNode).zIndex
                if z > maxZ
                    maxZ = z
                    nextWinId = id
            @open nextWinId

        @persistWindows()

    layoutBar: ->
        leftWidth = FS.getOuterWidth(@taskBarLeftAreaNode)
        rightWidth = FS.getOuterWidth(@taskBarRightAreaNode)
        FS.setCSS(@taskBarCenterAreaNode, left: FS.numberToPx(leftWidth), right: FS.numberToPx(rightWidth))

        width = FS.getInnerBoxWidth(@taskBarCenterAreaNode)
        num = F.objectSize @windows
        buttonOuterWidth = Math.floor width / num
        buttonOuterWidth = 180 if buttonOuterWidth > 180

        for id, w of @windows
            FS.setOuterWidth w.button, buttonOuterWidth

    openModalWindow: (options)->
        options.parent = @node
        options.modal = true
        win = new FS.Window(options)
        win.restoreLayout()
        win

    persistWindows: ->
        store = {}
        for wid, wo of @windows
            store[wid] = {func: wo.func, args: wo.args} if wo and wo.func
        localStorage.setItem("desk.windows", JSON.stringify(store))

        @persistWindowSort()

    persistWindowSort: ->
        windowNodes = @deskNode.querySelectorAll('.fw-window')
        if windowNodes
            winSort = []
            for winNode in windowNodes
                winId = winNode.getAttribute('winId')
                zIndex = getComputedStyle(winNode).zIndex
                zIndex = try parseInt(zIndex, 10)
                catch
                    0
                winSort.push {id: winId, index: zIndex}
            winSort = winSort.sort (a, b)-> a.index - b.index
            winSort2 = (w.id for w in winSort)
            localStorage.setItem("desk.windows.sort", JSON.stringify(winSort2))

    reopenWindows: ->
        sort = localStorage.getItem("desk.windows.sort")
        return unless sort
        sort = JSON.parse(sort)

        configs = localStorage.getItem("desk.windows")
        return unless configs
        configs = JSON.parse(configs)

        for winId in sort
            config = configs[winId]
            if config
                F.ofPropertyPath(window, config.func)?.apply null, config.args
            else
                console.log 'Cannot find window config ' + winId

        @persistWindowSort() # 保存状态！！

FS.Desk = Desk





