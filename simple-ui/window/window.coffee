# options.parent
# options.layout={left, top, outerWidth, outerHeight, innerWidth, innerHeight} 窗口的大小；初始位置，遵从绝对定位和 left/top 暂时只支持数字
# options.modal
# options.overlayZIndexStart
# options.overlayColor
# options.content 对话框内容
# options.resizable
# options.resizeOptions
# options.movable
# options.moveOptions
# options.title
# options.closable
# options.maximizable
# options.withBorder

# @dragAspect

class Window extends FS.EventEmitter
    constructor: (options)->
        @$parent = options.$parent
        @layout = options.layout
        @title = options.title
        @maximizable = options.maximizable ? true
        @modal = options.modal

        # 设置、配置所有者节点
        $parent = options.$parent
        $parent.css('position', 'relative') if $parent.css('position') == 'static'

        # 配置使用的遮罩层
        overlayZIndex = (options.overlayZIndexStart ? 10) # 不属于窗口，而属于 owner 节点管理？
        modalOverlayZIndex = overlayZIndex + 10

        if options.modal
            $overlay = $('<div/>', {class: "fw-modal-overlay", css: {zIndex: modalOverlayZIndex}}).appendTo($parent)
            $overlay.addClass 'fw-modal-fixed' if options.fixed
        else
            $overlay = $parent.find('> .fw-overlay')
            unless $overlay.length
                $overlay = $('<div/>', {class: "fw-overlay", css: {zIndex: overlayZIndex}}).appendTo($parent)
        @$overlay = $overlay

        # 创建窗口根元素
        @$window = $('<div/>', {class: "fw-window", css: {position: 'absolute'}}).appendTo(@$overlay)

        @$window.addClass 'with-border' if options.withBorder ? true

        # 初始化标题栏
        @$titleBar = $('<div/>', {class: "fw-window-title-bar"}).appendTo(@$window)

        @$title = $('<div/>', {class: "fw-window-title", html: options.title}).appendTo(@$titleBar)

        @$titleActions = $('<div/>', {class: "fw-window-actions"}).appendTo(@$titleBar)

        @$titleBar.on 'dblclick', => @toggleMaximize()

        # 最大化/恢复按钮
        if @maximizable
            @$maximizeBtn = FS.$LinkButton().addClass("fw-window-maximize iconfont icon-expand").appendTo(@$titleActions)
            @$maximizeBtn.on 'click', (e)=>
                @toggleMaximize()
                e.stopPropagation()
                e.preventDefault()

        if options.closable ? true
            # 关闭按钮
            @$closeBtn = FS.$LinkButton().addClass("fw-window-close iconfont icon-close").appendTo(@$titleActions)
            @$closeBtn.on 'click', (e)=>
                @close()
                e.stopPropagation()
                e.preventDefault()

        # 内容
        @$content = $('<div/>', {class: "fw-window-content"}).append(options.content).appendTo(@$window)

        if options.resizable
            @$window.resizable()

        if options.movable
            @$window.draggable({handle: @$titleBar[0]})

        # 最后，非模态的可能有多个窗口，需要把新创建的搞到前面来
        if not options.modal
            @toFront()
            @$window.on 'mousedown', => @toFront()

    restoreLayout: -> # 恢复初始位置
        layout = @layout

        parentClientWidth = @$parent.innerWidth()
        parentClientHeight = @$parent.innerHeight()

        # 宽度
        windowOuterWidth = if layout?.outerWidth
            Math.min(parentClientWidth, layout.outerWidth)
        else
            if FS.smallScreen # 小屏幕
                parentClientWidth
            else
                Math.min(parentClientWidth * .9, 1024)

        FS.setOuterWidth(@$window, windowOuterWidth)

        # 高度
        windowOuterHeight = if layout?.outerHeight
            Math.min(parentClientHeight, layout.outerHeight)
        else
            if FS.smallScreen # 小屏幕
                parentClientHeight
            else
                parentClientHeight * .75

        FS.setOuterHeight(@$window, windowOuterHeight)

        # 位置
        if @modal
            left = (parentClientWidth - windowOuterWidth) / 2
            top = (parentClientHeight - windowOuterHeight) / 2
        else
            $prev = @$window.prev()
            if $prev.length
                offset = $prev.position()
                left = offset.left + 10
                top = offset.top + 25
            else
                left = 10
                top = 25
        @$window.css {top: FS.numberToPx(top), left: FS.numberToPx(left)}

    toggleMaximize: ->
        if @maximized
            @maximized = false
            @$window.css @rectBeforeMaximized
        else
            @maximize()

    maximize: ->
        return unless @maximizable
        @maximized = true
        offset = @$window.position()
        @rectBeforeMaximized = {left: offset.left, top: offset.top, width: @$window.width(), height: @$window.height()}

        @$window.css {left: "0px", top: "0px"}

        FS.setOuterWidth(@$window, @$parent.innerWidth())
        FS.setOuterHeight(@$window, @$parent.innerHeight())

    close: ->
        @$window.remove()
        @$overlay.remove() unless @$overlay.children().length

        @fire 'AfterClosed'

    toFront: ->
        position = []
        $siblings = @$window.siblings()
        windowNode = @$window
        zIndexMax = 0
        $siblings.each (sibling)->
            return if sibling == windowNode
            zIndex = $(this).css('zIndex')
            zIndexMax = zIndex if zIndex > zIndexMax

        zIndexMax++

        @$window.css('zIndex', zIndex)

        @fire 'ToFront'

FS.Window = Window