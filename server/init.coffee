log = require './log'
Meta = require './Meta'
EntityService = require './service/EntityService'

exports.gInit = ->
    yield from gCreateAdminUser()
    yield from gAddDefaultMenu()

gCreateAdminUser = ->
    hasAdmin = yield from EntityService.gFindOneByCriteria(null, 'F_User', {admin: true})
    return if hasAdmin

    log.system.info 'Create default admin user'
    yield from EntityService.gCreate(null, 'F_User', {
        _id: Meta.newObjectId().toString(), admin: true
        username: 'admin', password: Meta.hashPassword('admin'),
    })

gAddDefaultMenu = ->
    hasMenu = yield from EntityService.gFindOneByCriteria(null, 'F_Menu', {})
    return if hasMenu

    log.system.info 'Create default menu'
    yield from EntityService.gCreate(null, 'F_Menu', defaultMenu)

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