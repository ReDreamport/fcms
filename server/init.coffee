log = require './log'
Meta = require './Meta'
EntityService = require './service/EntityService'

exports.gInit = ->
    yield from gCreateAdminUser()
    yield from gAddDefaultMenu()

gCreateAdminUser = ->
    userMeta = Meta.getEntityMeta('F_User')
    hasAdmin = yield from EntityService.gFindOneByCriteria(null, userMeta, {admin: true})
    return if hasAdmin

    log.system.info 'Create default admin user'
    yield from EntityService.gCreate(null, userMeta, {
        _id: Meta.newObjectId().toString(), admin: true
        username: 'admin', password: Meta.hashPassword('admin'),
    })

gAddDefaultMenu = ->
    menuMeta = Meta.getEntityMeta('F_Menu')
    hasMenu = yield from EntityService.gFindOneByCriteria(null, menuMeta, {})
    return if hasMenu

    log.system.info 'Create default menu'
    yield from EntityService.gCreate(null, menuMeta, defaultMenu)

defaultMenu = {
    "_version": 1,
    "menuGroups": [
        {
            "label": null,
            "menuItems": [
                {
                    "label": "用户",
                    "toEntity": "F_User",
                    "callFunc": null
                },
                {
                    "label": "Meta",
                    "toEntity": null,
                    "callFunc": "F.toMetaIndex"
                }
            ]
        }
    ]
}