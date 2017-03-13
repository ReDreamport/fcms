# 目标必须是绝对定位的，要考虑目标的 top/left（必须为像素、百分比，不能是 auto）
# 例如目标的可用高度将是限位区 Border 内高度 - top - 目标的 pbm
# 理论上绝对定位的元素，在设置了 width/height 的情况下，不能同时设置 top/bottom，left/right 亦然
# TODO 但暂不考虑目标的 right/bottom
FS.limitSizeIn = ($target, $limit)->
    limitWidth = $limit.innerWidth() - FS.cssAsNumber($target, 'left')
    limitHeight = $limit.innerHeight() - FS.cssAsNumber($target, 'top')

    limitWidth = Math.floor limitWidth
    limitHeight = Math.floor limitHeight

    {limitWidth, limitHeight}