error = require '../error'
config = require '../config'

UserService = require '../security/UserService'
SecurityCodeService = require '../security/SecurityCodeService'

checkPasswordFormat = (password, format)-> format.test password
exports.checkPasswordFormat = checkPasswordFormat

exports.clearUserSessionCookies = (ctx)->
    ctx.cookies.set('UserId', null, {signed: true, httpOnly: true})
    ctx.cookies.set('UserToken', null, {signed: true, httpOnly: true})

exports.gPing = ->
    if @state.user
        user = @state.user
        userToFront = {userId: user._id, admin: user.admin, acl: user.acl}
        userToFront.roles = {}
        if user.roles
            for roleId in user.roles
                role = yield from UserService.gRoleById(roleId)
                userToFront.roles[role.name] = role
        @body = userToFront
    else
        @status = 401

# 用户登录接口
exports.gSignIn = ->
    req = @request.body
    return @status == 400 unless req.username and req.password

    session = yield from UserService.gSignIn(req.username, req.password)
    @body = {userId: session.userId}

    @cookies.set('UserId', session.userId, {signed: true, httpOnly: true})
    @cookies.set('UserToken', session.userToken, {signed: true, httpOnly: true})

# 登出用户界面
exports.toSignOutPage = ->
    yield from UserService.gSignOut(@state.userId)

    # 清cookies
    exports.clearUserSessionCookies(this)

    @redirect('/sign-in')

# 登出接口
exports.gSignOut = ->
    yield from UserService.gSignOut(@state.userId)

    # 清cookies
    exports.clearUserSessionCookies(this)

    @status = 204

# 用户修改密码接口
exports.gChangePassword = ->
    req = @request.body

    unless checkPasswordFormat(req.newPassword, config.passwordFormat)
        throw new errors.UserError('BadPasswordFormat')

    yield from UserService.gChangePassword(@state.user._id, req.oldPassword, req.newPassword)

    # 清cookies
    exports.clearUserSessionCookies(this)

    @status = 204

# 通过手机/email重置密码
# phone/email, password, securityCode
exports.gResetPassword = ->
    req = @request.body

    unless checkPasswordFormat(req.password, config.passwordFormat)
        throw new errors.UserError('BadPasswordFormat')

    if req.phone?
        SecurityCodeServices.check(req.phone, req.securityCode)
        yield from UserService.gResetPasswordByPhone(req.phone, req.password)
    else if req.email?
        SecurityCodeServices.check(req.email, req.securityCode)
        yield from UserService.gResetPasswordByEmail(req.email, req.password)
    else
        @status = 400

    @status = 204

# 用户修改手机接口
exports.gChangePhone = ->
    req = @request.body

    # 检查验证码
    SecurityCodeService.check(req.phone, req.securityCode)

    yield from UserService.gChangePhone(@state.user._id, req.phone)

    @status = 204

# 用户修改 Email
exports.gChangeEmail = ->
    req = @request.body

    # 检查验证码
    SecurityCodeService.check(req.email, req.securityCode)

    yield from UserService.gChangeEmail(@state.user._id, req.email)

    @status = 204

