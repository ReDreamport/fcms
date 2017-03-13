# options.barScrollable
# options.barLeft
# options.barRight
class Tabbed
    constructor: (options)->
        options = options ? {}
        @node = FS.buildNode({classString: 'fw-tabbed', parent: options.parent})

        @barScrollable = options.barScrollable ? true

        @tabs = {}

        @headerNode = FS.buildNode(classString: "fw-header", parent: @node)

        @barNode = FS.buildNode(classString: "fw-bar", parent: @headerNode)
        @barNode.classList.add 'bar-scrollable' if @barScrollable
        @barNode.style.left = FS.numberToPx(options.barLeft) if options.barLeft
        @barNode.style.right = FS.numberToPx(options.barRight) if options.barRight

        @barScrollLeftBtn = FS.getFontIcon "fa-angle-left fa-2x scroll-left"
        @barNode.appendChild(@barScrollLeftBtn)
        @barScrollLeftBtn.addEventListener 'click', @scrollTabBar(40)

        @barScrollNode = FS.buildNode(classString: "fw-bar-scroll", parent: @barNode)

        @barScrollRightBtn = FS.getFontIcon "fa-angle-right fa-2x scroll-right"
        @barNode.appendChild(@barScrollRightBtn)
        @barScrollRightBtn.addEventListener 'click', @scrollTabBar(-40)

        @tabContainer = FS.buildNode(classString: "fw-tab-container", parent: @barScrollNode)

        @pageContainerNode = FS.buildNode(classString: "fw-pages", parent: @node)

    add: (id, options)->
        {title, content, closable} = options
        tabNode = FS.buildLinkButton(classString: 'fw-tab', parent: @tabContainer, content: title)
        tabNode.setAttribute('data-tab-id', id)

        if closable
            closeBtn = FS.getFontIcon "fa-close close-tab"
            tabNode.appendChild($closeBtn)
            $closeBtn.addEventListener 'click', (e)=>
                @close(id)
                e.stopPropagation()
                e.preventDefault()

        tabNode.addEventListener 'click', (e)=>
            @open(id)
            e.stopPropagation()
            e.preventDefault()

        content = content() if $.isFunction(content)

        pageNode = FS.buildNode(classString: 'fw-page', parent: @pageContainerNode, content: content)
        FS.setDisplay(pageNode, false)

        tab = {id: id, tabNode, pageNode}
        @tabs[id] = tab

        @layoutBar()

        return id

    addIfNotExisted: (id, options)->
        return false if @tabs[id]
        @add id, options
        true

    scrollTabBar: (move)->
        (e)=>
            style = getComputedStyle(@tabContainer)
            left = FS.pxToNumber(style.left) + move

            @tabContainer.style.left = FS.numberToPx(@clampBarScrollLeft(left))
            e.stopPropagation()
            e.preventDefault()

    scrollToTab: (tabId)->
        return unless @barScrollable

        for tabNode in @tabContainer.childNodes
            id = tabNode.getAttribute('data-tab-id')
            continue unless id == tabId

            rect = tabNode.getBoundingClientRect()
            style = getComputedStyle(tabNode)
            tabLeft = rect.left - FS.pxToNumber(style.marginLeft)
            tabRight = rect.right + FS.pxToNumber(style.marginRight)

            rect = @barScrollNode.getBoundingClientRect()
            scrollLeft = rect.left
            scrollRight = rect.right

            left = FS.pxToNumber(getComputedStyle(@tabContainer).left)

            if tabLeft < scrollLeft
                left = left + scrollLeft - tabLeft
            else if tabRight > scrollRight
                left = left + scrollRight - tabRight
            else
                return

            @tabContainer.style.left = FS.numberToPx(@clampBarScrollLeft(left))

    clampBarScrollLeft: (left)->
        outerWidth = FS.getOuterWidth(@tabContainer)
        minLeft = FS.pxToNumber(getComputedStyle(@barScrollNode).width) - outerWidth
        if minLeft > 0
            left = 0 # 不能滚
        else
            left = FS.clamp(left, minLeft, 0)
        left

    layoutBar: ->
        tabWidthSum = 0
        tabCount = 0
        for id, tab of @tabs
            tabWidthSum += FS.getOuterWidth(tab.tabNode)
            tabCount++

        if @barScrollable
            @tabContainer.style.width = FS.numberToPx(tabWidthSum)
        else
            return unless tabCount
            allWidth = @barNode.clientWidth # 无 padding
            tabOuterWidth = allWidth / tabCount
            tabWidth = tabOuterWidth - FS.getHorizontalPSBM(@tabContainer.firstElementChild)
            for n in @tabContainer.childNodes
                n.style.width = FS.floorToPx(tabWidth)

    open: (tabId)->
        tabId = tabId.toString()

        tab = @tabs[@activeTabId]
        if tab
            FS.setDisplay(tab.pageNode, false)
            tab.tabNode.classList.remove 'active'

        @activeTabId = tabId
        tab = @tabs[tabId]
        FS.setDisplay(tab.pageNode, true)
        tab.tabNode.classList.add 'active'

        @scrollToTab(tabId)

    close: (tabId)->
        tabId = tabId.toString()

        tab = @tabs[@activeTabId]
        return unless tab?

        if @activeTabId == tabId
            sibling = tab.tabNode.nextSibling || tab.tabNode.previousSibling
            nextTabId = sibling?.getAttribute('data-tab-id')

        tab = @tabs[tabId]
        delete @tabs[tabId]
        tab.tabNode.parentNode.removeChild(tab.tabNode)
        tab.pageNode.parentNode.removeChild(tab.pageNode)

        @layoutBar()

        @open nextTabId if nextTabId?

FS.Tabbed = Tabbed