FS = {}
window.FS = FS

FS.smallScreen = $(window).innerWidth() < 600

# =======================================================
# 值处理
# =======================================================

FS.floorToPx = (value) -> Math.floor(value) + "px"

FS.pxToNumber = (value) ->
    return 0 unless value
    return value if F.isNumberType value

    ms = value.match "^(.+)(px)?$"
    return if ms && ms.length
        parseFloat ms[1]
    else
        0

FS.numberToPx = (value) ->
    if F.isNumberType(value) then value + "px" else value

FS.clamp = (value, min, max)->
    return min if min? and value < min
    return max if max? and value > max
    value

# =======================================================
# 构建 DOM 节点
# =======================================================

buildNode = ({tag, classString, css, content, parent})->
    node = document.createElement(tag ? 'div')
    node.className = classString if classString?
    FS.setCSS(node, css) if css?
    FS.append node, content if content?
    parent.appendChild(node) if parent

    return node

FS.$LinkButton = ->
    $('<a />').attr('href', "javascript:")

FS.$FontIcon = (classString, size) ->
    $i = $('<i/>', {class: "fa " + classString})
    $i.css('fontSize', FS.numberToPx(size)) if size
    $i

FS.$FontIconButton = (iconClass, buttonClasses) ->
    buttonClassString = "fw-icon-button " + (buttonClasses ? "")
    $a = FS.$LinkButton().addClass(buttonClassString)

    FS.$FontIcon(iconClass).appendTo($a)
    $a

# =======================================================
# 读取、修改节点
# =======================================================

FS.setDisplay = ($node, display, visibleDisplay)->
    node = $node[0]
    if display
        node.style.display = visibleDisplay || node.getAttribute("data-original-display") || 'block'
    else
        style = getComputedStyle(node)
        node.setAttribute('data-original-display', style.display)
        node.style.display = 'none'

FS.getOuterSize = (node, computedStyle)->
    style = computedStyle || getComputedStyle(node)
    width = FS.getOuterWidth(node, style)
    height = FS.getOuterHeight(node, style)
    {width, height}

FS.getOuterWidth = ($node)-> $node.outerWidth(true)

FS.getOuterHeight = ($node)-> $node.outerHeight(true)

FS.setOuterWidth = ($node, outerWidth)->
    w = outerWidth - FS.getHorizontalPSBM($node)
    throw new Error("setOuterWidth too small") if w < 0
    $node.css 'width', FS.numberToPx(w)

FS.setOuterHeight = ($node, outerHeight)->
    # css 的 height 必须包含滚动条的高度
    h = outerHeight - FS.getVerticalPSBM($node)
    throw new Error("setOuterHeight too small") if h < 0
    $node.css 'height', FS.numberToPx(h)

FS.getInnerBoxWidth = ($node)-> $node.width()

FS.getInnerBoxHeight = ($node)-> $node.height()

FS.getClientWidth = ($node)-> $node.innerWidth()

FS.getClientHeight = ($node)-> $node.innerHeight()

# 带滚动条！
FS.getHorizontalPSBM = ($node)-> $node.outerWidth(true) - $node.innerWidth()

# 带滚动条！
FS.getVerticalPSBM = ($node)-> $node.outerHeight(true) - $node.innerHeight()

FS.cssAsNumber = ($node, attribute) -> FS.pxToNumber($node.css(attribute))