# window.onunhandledrejection = (reason, promise) -> false

F.$mainMenu = $('.main-menu')
F.$mainBody = $('.main-body')
F.$mainPages = $('.main-pages')
F.$mainOpened = $('.main-menu .open')

$('.exit', F.$mainBody).on 'click', ->
    location.href = "/sso/client/sign-out?callback=#{encodeURIComponent(location.href)}"

#=======================
# 收起展开菜单
#=======================

mainMenuCollapsed = false
F.collapseMainMenu = ->
    F.$mainMenu.addClass 'collapsed'
    F.$mainBody.addClass 'full'
    mainMenuCollapsed = true

F.notPCWidth = 1024
F.autoCollapseMainMenu = $(window).innerWidth() < F.notPCWidth
if F.autoCollapseMainMenu
    F.collapseMainMenu()
else
    mainMenuCollapsed = false

$('.toggle-main-menu').click ->
    if mainMenuCollapsed
        F.$mainMenu.removeClass 'collapsed'
        F.$mainBody.removeClass 'full'
        mainMenuCollapsed = false
    else
        F.collapseMainMenu()

#=======================
# 管理页面
#=======================

pages = {}
currentPage = null

F.removePage = (pageId)->
    page = pages[pageId]
    delete pages[pageId]

    if page
        page.$page.remove()
        page.$openItem.remove()

    if currentPage == page
        F.openPage(F.$mainPages.find('.page:last').attr('page-id'))

    persistOpenPages()

    if not F.$mainOpened.children().length
        F.$mainOpened.hide()

F.openPage = (pageId)->
    page = pages[pageId]
    return if page == currentPage

    F.$mainPages.find('.page').hide()

    if page
        page.$page.appendTo(F.$mainPages).show()
        currentPage = page

        persistOpenPages()

F.openOrAddPage = (pageId, title, func, args, creator)->
    page = pages[pageId]
    if page
        F.openPage(pageId)
    else
        F.$mainPages.find('.page').hide()
        $page = $(FT.Page({pageId, title})).appendTo(F.$mainPages)
        $openItem = $ FT.OpenedItem({name: title, pageId})
        F.$mainOpened.prepend $openItem
        F.$mainOpened.show()

        page = {$page, $openItem, func, args}
        currentPage = page
        pages[pageId] = page

        persistOpenPages()

        creator($page)

$(document).on 'click', '.close-page', ->
    F.removePage $(this).attr 'page-id'

persistOpenPages = ->
    pages2 = []
    F.$mainPages.find('.page').each (ele, index)->
        $this = $ this
        pageId = $this.attr 'page-id'

        page = pages[pageId]
        pages2.push {index, func: page.func, args: page.args || []} if page.func
    localStorage.setItem("_pages2", JSON.stringify(pages2))

reopenPages = ->
    F.$mainPages.empty()
    pages2 = localStorage.getItem("_pages2")
    return unless pages2
    pages2 = JSON.parse(pages2)
    pages2.sort (a, b)-> a.index - b.index
    for page in pages2
        F.ofPropertyPath(window, page.func)?.apply null, page.args

#=======================
# modal dialog
#=======================

F.openModalDialog = (options)->
    options.$parent = $(document.body)
    options.fixed = true
    options.modal = true
    options.resizable = true
    win = new FS.Window(options)
    win.restoreLayout()
    win

#=======================
# main()
#=======================

pingPromise = null
F.ping = (forced)->
    pingPromise = null if forced
    return pingPromise if pingPromise?

    F.logInit 'Ping...'
    pingPromise = F.api.get 'ping'
    pingPromise.then (user) ->
        F.logInit 'Ping Successfully'
        F.user = user

F.fetchMeta = ->
    F.logInit 'Fetching meta...'
    q = F.api.get "meta"
    q.then (meta)->
        F.logInit 'Meta fetched'
        F.meta = meta

F.gotUser = ->
    F.fetchMeta().then(F.initMenu).then ->
        F.initEntityGlobalEvent()
        reopenPages()

$ ->
    unless window.FormData
        message = "为了更好的使用体验，请使用现代浏览器，如 Chrome、Safari、最新版 IE 等。\n国产浏览器请使用极速模式，不要使用兼容模式。"
        F.toastWarning(message, 10000)

    F.logInit = F.log

    F.$mainPages.html ''
    mainQ = F.ping(true).then(F.gotUser)
    mainQ.catch ->
        F.logInit '初始化失败！'