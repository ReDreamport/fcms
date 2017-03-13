class ResizeAspect
    constructor: (options)->
        {targetNode, limitNode, minWidth, maxWidth, minHeight, maxHeight} = options

        @limitNode = limitNode
        @minWidth = minWidth
        @maxWidth = maxWidth
        @minHeight = minHeight
        @maxHeight = maxHeight

        targetNode.classList.add('fw-resizable')
        targetNodeComputedStyle = getComputedStyle(targetNode)
        targetOriginalPosition = targetNodeComputedStyle.position
        if targetOriginalPosition == 'static'
            targetNode.style.position = 'relative'

        rightDragHandle = FS.buildNode {
            parent: targetNode,
            classString: "drag-handle right-drag-handle",
            css: {width: ResizeAspect.dragHandleWidth + "px", right: (-ResizeAspect.dragHandleWidth / 2 ) + "px"}
        }

        bottomDragHandle = FS.buildNode {
            parent: targetNode,
            classString: "drag-handle bottom-drag-handle",
            css: {height: ResizeAspect.dragHandleWidth + "px", bottom: (-ResizeAspect.dragHandleWidth / 2) + "px"}
        }

        onDragHandleMouseDown = (allowChangeWidth, allowChangeHeight) ->
            (e)=>
                mouseDownClientX = e.clientX
                mouseDownClientY = e.clientY

                targetNodeComputedStyle = getComputedStyle(targetNode) # 重新计算
                initialWidth = FS.pxToNumber(targetNodeComputedStyle.width)
                initialHeight = FS.pxToNumber(targetNodeComputedStyle.height)

                # 推迟到这里计算，因为限制区域的大小可能发生变化，但在移动过程中发生变化就不管了
                if @limitNode
                    {limitWidth, limitHeight} = FS.limitSizeIn targetNode, targetOriginalPosition, @limitNode

                    maxWidth2 = if @maxWidth? then Math.min(@maxWidth, limitWidth) else limitWidth
                    maxHeight2 = if @maxHeight? then Math.min(@maxHeight, limitHeight) else limitHeight

                onMouseMove = (e)=>
                    width = FS.clamp initialWidth + e.clientX - mouseDownClientX, minWidth, maxWidth2
                    height = FS.clamp initialHeight + e.clientY - mouseDownClientY, minHeight, maxHeight2

                    targetNode.style.width = width + "px" if allowChangeWidth
                    targetNode.style.height = height + "px" if allowChangeHeight

                    e.stopPropagation()
                    e.preventDefault()

                onMouseUp = (e)=>
                    document.removeEventListener 'mousemove', onMouseMove, true
                    document.removeEventListener 'mouseup', onMouseUp, true

                    e.stopPropagation()
                    e.preventDefault()

                # 事件绑定到 window/document 比绑定到 body 上要好
                # 如果 body 不够高，比如极端情况下高度为0，则鼠标可能移出 body 区域，于是 body 收不到 move 事件
                # 另一种办法是在CSS中设置 html 和 body 的 height 为 100%；此时可以绑定事件到 body。注意必须设置 html 的 height，只设 body 不行。
                document.addEventListener 'mousemove', onMouseMove, true
                document.addEventListener 'mouseup', onMouseUp, true

                e.stopPropagation()
                e.preventDefault()

        rightDragHandle.addEventListener 'mousedown', onDragHandleMouseDown(true, false)
        bottomDragHandle.addEventListener 'mousedown', onDragHandleMouseDown(false, true)

ResizeAspect.dragHandleWidth = 6

FS.ResizeAspect = ResizeAspect
