# @disabled
# @limitElement
# @horizontalDrag
# @verticalDrag
# @droppable

class DragAspect
    constructor: (options)->
        {
        targetNode, dragHandlerNode,
        horizontalDrag, verticalDrag
        } = options

        @horizontalDrag = horizontalDrag ? true
        @verticalDrag = verticalDrag ? true

        onMouseDown = (e)=>
            return if @disabled

            mouseDownClientX = e.clientX # TODO 用视口坐标实际是不对的，因为可能视口坐标不变，滚动条在滚，鼠标仍在移动
            mouseDownClientY = e.clientY
            computedStyle = getComputedStyle(targetNode)

            # offsetX 包含 margin，减掉才是 CSS left/top
            # rootInitialLeft = targetNode.offsetLeft - FS.pxToNumber(computedStyle.marginLeft)
            # rootInitialTop = targetNode.offsetTop - FS.pxToNumber(computedStyle.marginTop)
            rootInitialLeft = FS.pxToNumber(computedStyle.left)
            rootInitialTop = FS.pxToNumber(computedStyle.top)

            # 推迟到这里计算，因为定位祖先或限制区域可能发生变化，但在移动过程中发生变化就不管了
            # {topMin, topMax, leftMin, leftMax} = FS.limitPositionIn targetNode, @limitNode if @limitNode

            onMouseMove = (e)=>
                #left = FS.clamp(rootInitialLeft + e.clientX - mouseDownClientX, leftMin, leftMax)
                #top = FS.clamp(rootInitialTop + e.clientY - mouseDownClientY, topMin, topMax)
                left = rootInitialLeft + e.clientX - mouseDownClientX
                top = rootInitialTop + e.clientY - mouseDownClientY

                if @horizontalDrag
                    targetNode.style.left = left + "px"
                if @verticalDrag
                    targetNode.style.top = top + "px"

                #if droppable
                #    FS.droppable.willDrop(dropTag, targetNode.getBoundingClientRect())

                e.stopPropagation()
                e.preventDefault()

            onMouseUp = (e)=>
                document.removeEventListener 'mousemove', onMouseMove, true
                document.removeEventListener 'mouseup', onMouseUp, true

                # if droppable
                #     FW.droppable.doDrop(dropTag, targetNode.getBoundingClientRect(), targetNode)

                e.stopPropagation()
                e.preventDefault()

            # 事件绑定到 window/document 比绑定到 body 上要好
            # 如果 body 不够高，比如极端情况下高度为0，则鼠标可能移出 body 区域，于是 body 收不到 move 事件
            # 另一种办法是在CSS中设置 html 和 body 的 height 为 100%；此时可以绑定事件到 body。注意必须设置 html 的 height，只设 body 不行。
            document.addEventListener 'mouseup', onMouseUp, true
            document.addEventListener 'mousemove', onMouseMove, true

            # e.stopPropagation() 应该继续传播
            e.preventDefault()

        if dragHandlerNode
            dragHandlerNode.classList.add 'fw-drag-handler'
            dragHandlerNode.addEventListener 'mousedown', onMouseDown, false
        else
            targetNode.addEventListener 'mousedown', onMouseDown, false

FS.DragAspect = DragAspect