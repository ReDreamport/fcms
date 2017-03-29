# 菜单权限、按钮权限、端点权限、实体权限（增删改查）、字段权限（读、填、改）

util = require '../util'

exports.permissionArrayToMap = (acl)->
    return acl unless acl?
    acl.menu = util.arrayToTrueObject(acl.menu)
    acl.button = util.arrayToTrueObject(acl.button)
    acl.action = util.arrayToTrueObject(acl.action)

    if acl.entity
        entities = acl.entity
        entities[entityName] = util.arrayToTrueObject(v) for entityName, v of entities

    if acl.field
        entities = acl.field
        for entityName, e of entities
            for fieldName, field of e
                e[fieldName] = util.arrayToTrueObject(field) if field