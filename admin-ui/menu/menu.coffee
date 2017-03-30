fetchMenu = ->
    F.logInit 'Fetching menu data...'
    q = F.api.get 'entity/F_Menu?pageNo=1&pageSize=1'
    q = q.then (r)->
        F.logInit 'Menu data fetched'
        r.page?[0]
    q.catch (e)->
        q = null
        throw e

canAccessMenu = (target)->
    user = F.user
    return true if user.acl.menu?[target]
    if user.roles
        for rn, role of user.roles
            return true if role.acl.menu?[target]
    false

F.initMenu = ->
    fetchMenu().then (menuData)->
        F.menuData = menuData
        menuGroupsShown = []
        if menuData
            menuGroups = menuData?.menuGroups || []
            menuGroupsShown = []
            for menuGroup in menuGroups
                menuItems = menuGroup.menuItems
                menuItemsShown = []
                for menuItem in menuItems
                    if F.user.admin
                        menuItemsShown.push(menuItem)
                    else if menuItem.callFunc
                        menuItemsShown.push(menuItem) if canAccessMenu(menuItem.callFunc)
                    else if menuItem.toEntity
                        menuItemsShown.push(menuItem) if canAccessMenu(menuItem.toEntity)
                if menuItemsShown.length
                    menuGroup2 = F.cloneByJSON(menuGroup)
                    menuGroup2.menuItems = menuItemsShown
                    menuGroupsShown.push menuGroup2

        $items = $('.main-menu .menu-items').empty()

        $items.html FT.MenuItems({menuGroups: menuGroupsShown})

        $items.on 'click', '.call-func', ->
            func = $(this).attr('func')
            F.ofPropertyPath(window, func)?()

        $items.on 'click', '.menu-item', ->
            F.collapseMainMenu() if F.autoCollapseMainMenu

        F.$mainMenu.on 'click', '.open-item', ->
            F.openPage $(this).attr('page-id')
            F.collapseMainMenu() if F.autoCollapseMainMenu

