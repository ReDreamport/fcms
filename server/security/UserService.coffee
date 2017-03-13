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

userMeta = null
userRoleMeta = null
userSessionMeta = null

exports.gInit = ->
    userMeta = Meta.getEntityMeta('F_User')
    userRoleMeta = Meta.getEntityMeta("F_UserRole")
    userSessionMeta = Meta.getEntityMeta("F_UserSession")

    EntityServiceCache = require '../service/EntityServiceCache'
    EntityServiceCache.onUpdatedOrRemoved (ctx, entityMeta, ids)=>
        if entityMeta.name == 'F_User'
            for id in ids
                delete userCache[id]
        else if entityMeta.name == 'F_UserRole'
            anonymousRole = null
            for id in ids
                delete roleCache[id]

    yield from _gAddInitAdmin()

exports.gUserById = (id)->
    user = userCache[id]
    return user if user

    user = yield from EntityService.gFindOneByCriteria({}, userMeta, {_id: id})
    if user
        userCache[id] = user
        PermissionService.permissionArrayToSet(user.acl)
    user

exports.gRoleById = (id)->
    role = roleCache[id]
    return role if role

    role = yield from EntityService.gFindOneByCriteria({}, userRoleMeta, {_id: id})
    if role
        roleCache[id] = role
        PermissionService.permissionArrayToSet(role.acl)
    role

exports.gGetAnonymousRole = ->
    return anonymousRole if anonymousRole

    role = yield from EntityService.gFindOneByCriteria({}, userRoleMeta, {name: 'anonymous'})
    if role
        anonymousRole = role
        PermissionService.permissionArrayToSet(role.acl)
    role

exports.gAuthToken = (userId, userToken)->
    session = yield from EntityService.gFindOneByCriteria({}, userSessionMeta, {userId})
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

    user = yield from EntityService.gFindOneByCriteria({}, userMeta, criteria)

    throw new error.UserError("UserNotExisted") unless user?
    throw new error.UserError("UserDisabled") if user.disabled
    throw new error.UserError("PasswordNotMatch") if Meta.hashPassword(password) != user.password

    session = {}
    session.userId = user._id
    session.userToken = chance.string(length: 20)
    session.expireAt = Date.now() + config.sessionExpireAtServer

    yield from exports.gSignOut(user._id) # 先退出
    yield from EntityService.gCreate({}, userSessionMeta, session)

    session

# 登出
exports.gSignOut = (userId)->
    criteria = {userId: userId}
    yield from EntityService.gRemoveManyByCriteria({}, userSessionMeta, criteria)

# 添加用户（核心信息）
exports.gAddUser = (userInput)->
    user =
        _id: Meta.newObjectId().toString() # 用户 ID 同一直接用字符串
        username: userInput.username, password: userInput.password
        phone: userInput.phone, email: userInput.email

    yield from EntityService.gCreate({}, userMeta, user)

# 修改绑定的手机
exports.gChangePhone = (userId, phone)->
    user = yield from EntityService.gFindOneByCriteria({}, userMeta, {_id: userId})
    throw new error.UserError("UserNotExisted") unless user?
    throw new error.UserError("UserDisabled") if user.disabled

    yield from EntityService.gUpdateByIdVersion({}, userMeta, userId, user._version, {phone: phone})

    delete userCache[userId]

# 修改绑定的邮箱
exports.gChangeEmail = (userId, email)->
    user = yield from EntityService.gFindOneByCriteria({}, userMeta, {_id: userId})
    throw new error.UserError("UserNotExisted") unless user?
    throw new error.UserError("UserDisabled") if user.disabled

    yield from EntityService.gUpdateByIdVersion({}, userMeta, userId, user._version, {email: email})

    delete userCache[userId]

# 修改密码
exports.gChangePassword = (userId, oldPassword, newPassword)->
    user = yield from EntityService.gFindOneByCriteria({}, userMeta, {_id: userId})
    throw new error.UserError("UserNotExisted") unless user?
    throw new error.UserError("UserDisabled") if user.disabled
    throw new error.UserError("PasswordNotMatch") if Meta.hashPassword(oldPassword) != user.password

    update = {password: Meta.hashPassword(newPassword)}
    yield from EntityService.gUpdateByIdVersion({}, userMeta, userId, user._version, update)

    yield from _gRemoveAllUserSessionOfUser userId

# 通过手机重置密码
exports.gResetPasswordByPhone = (phone, password)->
    user = yield from EntityService.gFindOneByCriteria({}, userMeta, {phone: phone})
    throw new error.UserError("UserNotExisted") unless user?
    throw new error.UserError("UserDisabled") if user.disabled

    update = {password: Meta.hashPassword(password)}
    yield from EntityService.gUpdateByIdVersion({}, userMeta, user._id, user._version, update)

    yield from _gRemoveAllUserSessionOfUser user._id

# 通过邮箱重置密码
exports.gResetPasswordByEmail = (email, password)->
    user = yield from EntityService.gFindOneByCriteria({}, userMeta, {email: email})
    throw new error.UserError("UserNotExisted") unless user?
    throw new error.UserError("UserDisabled") if user.disabled

    update = {password: Meta.hashPassword(password)}
    yield from EntityService.gUpdateByIdVersion({}, userMeta, user._id, user._version, update)

    yield from _gRemoveAllUserSessionOfUser user._id

_gRemoveAllUserSessionOfUser = (userId) ->
    yield from EntityService.gRemoveManyByCriteria({}, userSessionMeta, {useId: userId})

_gAddInitAdmin = ->
    hasAdmin = yield from EntityService.gFindOneByCriteria(null, userMeta, {admin: true})
    return if hasAdmin

    log.system.info 'Create default admin user'
    yield from EntityService.gCreate(null, userMeta, {
        _id: Meta.newObjectId().toString(), admin: true
        username: 'admin', password: Meta.hashPassword('admin'),
    })