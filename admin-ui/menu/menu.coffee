fetchMenu = ->
    F.$mainPages.html 'fetching menu...'
    q = F.api.get 'entity/F_Menu?pageNo=1&pageSize=1'
    q.catch -> q = null
    q.then (r)-> r.page?[0]

F.initMenu = ->
    hasPermission = F.hasPermission

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
                        menuItemsShown.push(menuItem) if hasPermission('menuPermissions', menuItem.callFunc)
                    else if menuItem.toEntity
                        canListEntity = (hasPermission('entityPermissions', '*/' + menuItem.toEntity) or
                            hasPermission('entityPermissions', 'ListEntity/' + menuItem.toEntity))
                        if canListEntity and hasPermission('urlPermissions', 'ListEntity')
                            menuItemsShown.push(menuItem)
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

