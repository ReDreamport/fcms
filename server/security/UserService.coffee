chance = new require('chance')()

error = require '../error'
log = require '../log'
Meta = require '../Meta'
config = require '../config'

EntityService = require '../service/EntityService'

PermissionService = require './PermissionService'

userCache = {}
roleCache = {}
anonymousRole = null

exports.init = ->
    EntityServiceCache = require '../service/EntityServiceCache'
    EntityServiceCache.onUpdatedOrRemoved (ctx, entityMeta, ids)=>
        if entityMeta.name == 'F_User'
            if ids
                delete userCache[id] for id in ids
            else
                userCache = {}
        else if entityMeta.name == 'F_UserRole'
            anonymousRole = null
            if ids
                delete roleCache[id] for id in ids
            else
                roleCache = {}

exports.gUserById = (id)->
    user = userCache[id]
    return user if user

    user = yield from EntityService.gFindOneByCriteria({}, 'F_User', {_id: id})
    if user
        userCache[id] = user
        PermissionService.permissionArrayToMap(user.acl)
    user

exports.gRoleById = (id)->
    role = roleCache[id]
    return role if role

    role = yield from EntityService.gFindOneByCriteria({}, 'F_UserRole', {_id: id})
    if role
        roleCache[id] = role
        PermissionService.permissionArrayToMap(role.acl)
    role

exports.gGetAnonymousRole = ->
    return anonymousRole if anonymousRole

    role = yield from EntityService.gFindOneByCriteria({}, 'F_UserRole', {name: 'anonymous'})
    if role
        anonymousRole = role
        PermissionService.permissionArrayToSet(role.acl)
    role

exports.gAuthToken = (userId, userToken)->
    session = yield from EntityService.gFindOneByCriteria({}, 'F_UserSession', {userId})
    return false unless session

    if session.userToken != userToken
        log.debug 'token not match', {userId, userToken, sessionUserToken: session.userToken}
        return false

    if session.expireAt < Date.now()
        log.debug 'token expired', {userId, expireAt: session.expireAt}
        return false

    yield from exports.gUserById(userId)

# 登录
# TODO 思考：如果用户之前登录此子应用的 session 未过期，是返回之前的 session 还是替换 session
exports.gSignIn = (username, password)->
    throw new error.UserError("PasswordNotMatch") unless password

    usernameFields = config.usernameFields
    usernameFields = ["username", "phone", "email"] unless usernameFields && usernameFields.length

    matchFields = ({field: f, operator: "==", value: username} for f in usernameFields)
    criteria = {__type: 'relation', relation: 'or', items: matchFields}

    user = yield from EntityService.gFindOneByCriteria({}, 'F_User', criteria)

    throw new error.UserError("UserNotExisted") unless user?
    throw new error.UserError("UserDisabled") if user.disabled
    throw new error.UserError("PasswordNotMatch") if Meta.hashPassword(password) != user.password

    session = {}
    session.userId = user._id
    session.userToken = chance.string(length: 20)
    session.expireAt = Date.now() + config.sessionExpireAtServer

    yield from exports.gSignOut(user._id) # 先退出
    yield from EntityService.gCreate({}, 'F_UserSession', session)

    session

# 登出
exports.gSignOut = (userId)->
    criteria = {userId: userId}
    yield from EntityService.gRemoveManyByCriteria({}, 'F_UserSession', criteria)

# 添加用户（核心信息）
exports.gAddUser = (userInput)->
    user =
        _id: Meta.newObjectId().toString() # 用户 ID 同一直接用字符串
        username: userInput.username, password: userInput.password
        phone: userInput.phone, email: userInput.email

    yield from EntityService.gCreate({}, 'F_User', user)

# 修改绑定的手机
exports.gChangePhone = (userId, phone)->
    user = yield from EntityService.gFindOneByCriteria({}, 'F_User', {_id: userId})
    throw new error.UserError("UserNotExisted") unless user?
    throw new error.UserError("UserDisabled") if user.disabled

    yield from EntityService.gUpdateOneByCriteria({}, 'F_User', {_id: userId, _version: user._version}, {phone: phone})

    delete userCache[userId]

# 修改绑定的邮箱
exports.gChangeEmail = (userId, email)->
    user = yield from EntityService.gFindOneByCriteria({}, 'F_User', {_id: userId})
    throw new error.UserError("UserNotExisted") unless user?
    throw new error.UserError("UserDisabled") if user.disabled

    yield from EntityService.gUpdateOneByCriteria({}, 'F_User', {_id: userId, _version: user._version}, {email: email})

    delete userCache[userId]

# 修改密码
exports.gChangePassword = (userId, oldPassword, newPassword)->
    user = yield from EntityService.gFindOneByCriteria({}, 'F_User', {_id: userId})
    throw new error.UserError("UserNotExisted") unless user?
    throw new error.UserError("UserDisabled") if user.disabled
    throw new error.UserError("PasswordNotMatch") if Meta.hashPassword(oldPassword) != user.password

    update = {password: Meta.hashPassword(newPassword)}
    yield from EntityService.gUpdateOneByCriteria({}, 'F_User', {_id: userId, _version: user._version}, update)

    yield from _gRemoveAllUserSessionOfUser userId

# 通过手机重置密码
exports.gResetPasswordByPhone = (phone, password)->
    user = yield from EntityService.gFindOneByCriteria({}, 'F_User', {phone: phone})
    throw new error.UserError("UserNotExisted") unless user?
    throw new error.UserError("UserDisabled") if user.disabled

    update = {password: Meta.hashPassword(password)}
    yield from EntityService.gUpdateOneByCriteria({}, 'F_User', {_id: user._id, _version: user._version}, update)

    yield from _gRemoveAllUserSessionOfUser user._id

# 通过邮箱重置密码
exports.gResetPasswordByEmail = (email, password)->
    user = yield from EntityService.gFindOneByCriteria({}, 'F_User', {email: email})
    throw new error.UserError("UserNotExisted") unless user?
    throw new error.UserError("UserDisabled") if user.disabled

    update = {password: Meta.hashPassword(password)}
    yield from EntityService.gUpdateOneByCriteria({}, 'F_User', {_id: user._id, _version: user._version}, update)

    yield from _gRemoveAllUserSessionOfUser user._id

exports.checkUserHasRoleId = (user, roleId)->
    roleId = roleId.toString()
    if user.roles
        for r in user.roles
            return true if r._id.toString() == roleId
    return false

_gRemoveAllUserSessionOfUser = (userId) ->
    yield from EntityService.gRemoveManyByCriteria({}, 'F_UserSession', {useId: userId})