# 菜单权限、按钮权限、端点权限、实体权限（增删改查）、字段权限（读、填、改）

exports.permissionArrayToSet = (acl)->
    return acl unless acl?
    acl.menu = new Set(acl.menu) if acl.menu
    acl.button = new Set(acl.button) if acl.button
    acl.action = new Set(acl.action) if acl.action
    acl.entity = new Set(acl.entity) if acl.entity
    acl.field = new Set(acl.field) if acl.field