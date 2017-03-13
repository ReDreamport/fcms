# 注意 sortable 项完全可能嵌套！！！！

FS.sortable = ({$container, sortableNodeSelector})->
    $container.addClass 'fw-sortable'

    $container.on 'mousedown', (e)->
        # 返回 true，表示不阻止冒泡
        return true unless e.target
        $item = $(e.target).closest(sortableNodeSelector)
        return true unless $item.length

        unless $item.closest('.fw-sortable').is($container) # 防止 sortable 嵌套导致的问题
            console.log 'sortable 不归我管'
            return true

        $itemParent = $item.parent()
        $items = $itemParent.children(sortableNodeSelector)
        unless $items.length > 1 # 只有一项也不能拖
            console.log '只有一个元素不能拖动'
            return true

        console.log "maybe sortable"

        ctx = {}

        itemNode = $item[0]

        ctx.lastClientX = e.clientX # 上一次处理的鼠标位置
        ctx.lastClientY = e.clientY
        ctx.clientX = e.clientX # 鼠标当前位置
        ctx.clientY = e.clientY

        # 判断插入位置提示符应该显示在项的左右还是项的上下
        # 对于水平摆列或网格排列的项，提示符放左右（左右拖动有效）；对于垂直排列的项，提示符放上下（上下拖动有效）
        item1Rect = $items[0].getBoundingClientRect()
        item2Rect = $items[1].getBoundingClientRect()
        verticalDrag = item2Rect.top >= item1Rect.bottom
        console.log '垂直拖动' + verticalDrag

        onMouseMove = (e)->
            ctx.clientX = e.clientX
            ctx.clientY = e.clientY

            e.preventDefault() if ctx.dragStarted # 防止拖动过程中选中文本

            return !ctx.dragStarted # 返回 true 让事件继续冒泡

        onMouseUp = ->
            console.log 'drag end, mouse up'
            if ctx.dropTimer
                clearTimeout(ctx.dropTimer)

            if ctx.startDragTimer
                clearTimeout(ctx.startDragTimer)

            $itemParent.css('position', ctx.listInitPosition) if ctx.listInitPosition?
            $item.css('position', ctx.itemInitPosition) if ctx.itemInitPosition?
            itemNode.style.background = ctx.itemInitStyleBackground
            itemNode.style.boxShadow = ctx.itemInitStyleBoxShadow

            document.body.style.cursor = null

            r = !ctx.dragStarted # 返回 true 让事件继续冒泡

            $(document).off('mousemove', onMouseMove).off('mouseup', onMouseUp)

            return r

        console.log "bind mouse move/up event"
        $(document).on('mousemove', onMouseMove).on('mouseup', onMouseUp)

        ctx.startDragTimer = setTimeout((->
            ctx.startDragTimer = null
            ctx.dragStarted = true

            ctx.itemInitPosition = $item.css('position')
            if ctx.itemInitPosition == 'static'
                $item.css('position', 'relative')
            ctx.itemInitStyleBackground = itemNode.style.background
            itemNode.style.background = "rgba(200,200,200,0.8)"
            ctx.itemInitStyleBoxShadow = itemNode.style.boxShadow
            itemNode.style.boxShadow = "0 0 6px #333"

            ctx.listInitPosition = $itemParent.css('position')
            if ctx.listInitPosition == 'static'
                $itemParent.css('position', 'relative')

            FS.setCSS(itemNode, {top: "0px", left: "0px"})

            document.body.style.cursor = "move" # 修改鼠标指针！！！！

            ctx.dropTimer = setInterval((->
                return if ctx.clientX == ctx.lastClientX and ctx.clientY == ctx.lastClientY

                itemCs = getComputedStyle(itemNode)
                FS.setCSS(itemNode, {
                    left: FS.numberToPx(FS.pxToNumber(itemCs.left) + ctx.clientX - ctx.lastClientX)
                    top: FS.numberToPx(FS.pxToNumber(itemCs.top) + ctx.clientY - ctx.lastClientY)
                })

                mouseX = ctx.lastClientX = ctx.clientX
                mouseY = ctx.lastClientY = ctx.clientY

                # 判定是否要移动节点在文档中的位置
                $items = $itemParent.children(sortableNodeSelector)
                itemsNum = $items.length
                $items.each (index)->
                    return true if this == itemNode
                    childRect = this.getBoundingClientRect()
                    if verticalDrag # 垂直拖动
                        if mouseY < childRect.top + childRect.height / 2
                            if this != itemNode.nextElementSibling
                                this.parentNode.insertBefore(itemNode, this)
                                FS.setCSS(itemNode, {left: "0px", top: "0px"})
                            return false
                        if index == itemsNum - 1 and mouseY > childRect.top + childRect.height / 2
                            $itemParent.append($item)
                            FS.setCSS(itemNode, {left: "0px", top: "0px"})
                            return false
                    else # 水平拖动有效
                        if mouseX < childRect.left + childRect.width / 2
                            if this != itemNode.nextElementSibling
                                this.parentNode.insertBefore(itemNode, this)
                                FS.setCSS(itemNode, {left: "0px", top: "0px"})
                            return false
                        if index == itemsNum - 1 and mouseX > childRect.left + childRect.width / 2
                            $itemParent.append($item)
                            FS.setCSS(itemNode, {left: "0px", top: "0px"})
                            return false
                    return true
            ), 50)
        ), 250)

        return true # 返回 true 让事件继续冒泡