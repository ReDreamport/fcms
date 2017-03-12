chance = new require('chance')()

util = require '../util'
error = require '../error'

Meta = require '../Meta'

PermissionService = require './PermissionService'

class UserService
    constructor: (@app)->
        @userCache = {}
        @roleCache = {}

        meta = @app.meta
        @userMeta = meta.getEntityMeta('F_User')
        @userRoleMeta = meta.getEntityMeta("F_UserRole")
        @userSessionMeta = meta.getEntityMeta("F_UserSession")

        @app.entityCache.onUpdatedOrRemoved (ctx, entityMeta, ids)=>
            if entityMeta.name == 'F_User'
                for id in ids
                    delete @userCache[id]
            else if entityMeta.name == 'F_UserRole'
                @anonymousRole = null
                for id in ids
                    delete @roleCache[id]

    gInit: ->
        db = yield from @app.mongo.gDatabase()
        c = db.collection(@userMeta.tableName)
        userCount = yield c.count({})
        if userCount == 0
            @app.log.system.info 'Create default admin user!!!'
            yield c.insertOne({
                _id: Meta.newObjectId().toString(), admin: true
                username: 'admin', password: Meta.hashPassword('admin'),
            })

    gUserById: (id)->
        user = @userCache[id]
        return user if user

        user = yield from @app.entityService.gFindOneByCriteria({}, @userMeta, {_id: id})
        if user
            @userCache[id] = user
            PermissionService.permissionArrayToSet(user.acl)
        user

    gRoleById: (id)->
        role = @roleCache[id]
        return role if role

        role = yield from @app.entityService.gFindOneByCriteria({}, @userRoleMeta, {_id: id})
        if role
            @roleCache[id] = role
            PermissionService.permissionArrayToSet(role.acl)
        role

    gGetAnonymousRole: ->
        return @anonymousRole if @anonymousRole

        role = yield from @app.entityService.gFindOneByCriteria({}, @userRoleMeta, {name: 'anonymous'})
        if role
            @anonymousRole = role
            PermissionService.permissionArrayToSet(role.acl)
        role

    gAuthToken: (userId, userToken)->
        session = yield from @app.entityService.gFindOneByCriteria({}, @userSessionMeta, {userId})
        unless session
            # @app.log.debug 'no such session', subApp, userId
            return false

        if session.userToken != userToken
            @app.log.debug 'token not match', {userId, userToken, sessionUserToken: session.userToken}
            return false

        if session.expireAt < Date.now()
            @app.log.debug 'token expired', {userId, expireAt: session.expireAt}
            return false

        yield from @gUserById(userId)

    # 登录
    # TODO 思考：如果用户之前登录此子应用的 session 未过期，是返回之前的 session 还是替换 session
    gSignIn: (username, password)->
        throw new error.UserError("PasswordNotMatch") unless password

        usernameFields = @app.config.usernameFields
        usernameFields = ["username", "phone", "email"] unless usernameFields && usernameFields.length

        matchFields = ({field: f, operator: "==", value: username} for f in usernameFields)
        criteria = {__type: 'relation', relation: 'or', items: matchFields}

        user = yield from @app.entityService.gFindOneByCriteria({}, @userMeta, criteria)

        throw new error.UserError("UserNotExisted") unless user?
        throw new error.UserError("UserDisabled") if user.disabled
        throw new error.UserError("PasswordNotMatch") if Meta.hashPassword(password) != user.password

        session = {}
        session.userId = user._id
        session.userToken = chance.string(length: 20)
        session.expireAt = Date.now() + @app.config.sessionExpireAtServer

        yield from @gSignOut(user._id) # 先退出
        yield from @app.entityService.gCreate({}, @userSessionMeta, session)

        session

    # 登出
    gSignOut: (userId)->
        criteria = {userId: userId}
        yield from @app.entityService.gRemoveManyByCriteria({}, @userSessionMeta, criteria)

    # 添加用户（核心信息）
    gAddUser: (userInput)->
        user =
            _id: Meta.newObjectId().toString() # 用户 ID 同一直接用字符串
            username: userInput.username, password: userInput.password
            phone: userInput.phone, email: userInput.email

        yield from @app.entityService.gCreate({}, "F_User", user)

    # 修改绑定的手机
    gChangePhone: (userId, phone)->
        user = yield from @app.entityService.gFindOneByCriteria({}, @userMeta, {_id: userId})
        throw new error.UserError("UserNotExisted") unless user?
        throw new error.UserError("UserDisabled") if user.disabled

        yield from @app.entityService.gUpdateByIdVersion({}, @userMeta, userId, user._version, {phone: phone})

        delete @userCache[userId]

    # 修改绑定的邮箱
    gChangeEmail: (userId, email)->
        user = yield from @app.entityService.gFindOneByCriteria({}, @userMeta, {_id: userId})
        throw new error.UserError("UserNotExisted") unless user?
        throw new error.UserError("UserDisabled") if user.disabled

        yield from @app.entityService.gUpdateByIdVersion({}, @userMeta, userId, user._version, {email: email})

        delete @userCache[userId]

    # 修改密码
    gChangePassword: (userId, oldPassword, newPassword)->
        user = yield from @app.entityService.gFindOneByCriteria({}, "F_User", {_id: userId})
        throw new error.UserError("UserNotExisted") unless user?
        throw new error.UserError("UserDisabled") if user.disabled
        throw new error.UserError("PasswordNotMatch") if Meta.hashPassword(oldPassword) != user.password

        update = {password: Meta.hashPassword(newPassword)}
        yield from @app.entityService.gUpdateByIdVersion({}, @userMeta, userId, user._version, update)

        yield from @_gRemoveAllUserSessionOfUser userId

    # 通过手机重置密码
    gResetPasswordByPhone: (phone, password)->
        user = yield from @app.entityService.gFindOneByCriteria({}, @userMeta, {phone: phone})
        throw new error.UserError("UserNotExisted") unless user?
        throw new error.UserError("UserDisabled") if user.disabled

        update = {password: Meta.hashPassword(password)}
        yield from @app.entityService.gUpdateByIdVersion({}, @userMeta, user._id, user._version, update)

        yield from @_gRemoveAllUserSessionOfUser user._id

    # 通过邮箱重置密码
    gResetPasswordByEmail: (email, password)->
        user = yield from @app.entityService.gFindOneByCriteria({}, @userMeta, {email: email})
        throw new error.UserError("UserNotExisted") unless user?
        throw new error.UserError("UserDisabled") if user.disabled

        update = {password: Meta.hashPassword(password)}
        yield from @app.entityService.gUpdateByIdVersion({}, @userMeta, user._id, user._version, update)

        yield from @_gRemoveAllUserSessionOfUser user._id

    _gRemoveAllUserSessionOfUser: (userId) ->
        yield from @app.entityService.gRemoveManyByCriteria({}, @userSessionMeta, {useId: userId})

exports.UserService = UserService