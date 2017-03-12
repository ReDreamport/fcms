error = require '../error'

checkPasswordFormat = (password, format)-> format.test password
exports.checkPasswordFormat = checkPasswordFormat

exports.clearUserSessionCookies = (ctx, app)->
    ctx.cookies.set(app.name + 'UserId', null, {signed: true, httpOnly: true})
    ctx.cookies.set(app.name + 'UserToken', null, {signed: true, httpOnly: true})

exports.gPing = ->
    app = @state.app
    if @state.user
        user = @state.user
        userToFront = {userId: user._id, admin: user.admin, acl: user.acl}
        userToFront.roles = {}
        if user.roles
            for roleId in user.roles
                role = yield from app.userService.gRoleById(roleId)
                userToFront.roles[role.name] = role
        @body = userToFront
    else
        @status = 401

# 用户登录接口
exports.gSignIn = ->
    app = @state.app
    req = @request.body
    return @status == 400 unless req.username and req.password

    session = yield from app.userService.gSignIn(req.username, req.password)
    @body = {userId: session.userId}

    @cookies.set(app.name + 'UserId', session.userId, {signed: true, httpOnly: true})
    @cookies.set(app.name + 'UserToken', session.userToken, {signed: true, httpOnly: true})

# 登出用户界面
exports.toSignOutPage = ->
    app = @state.app
    yield from app.userService.gSignOut(@state.userId)

    # 清cookies
    exports.clearUserSessionCookies(this, app)

    @redirect('/sign-in')

# 登出接口
exports.gSignOut = ->
    app = @state.app
    yield from app.userService.gSignOut(@state.userId)

    # 清cookies
    exports.clearUserSessionCookies(this, app)

    @status = 204

# 用户修改密码接口
exports.gChangePassword = ->
    app = @state.app
    req = @request.body

    unless checkPasswordFormat(req.newPassword, app.config.passwordFormat)
        throw new errors.UserError('BadPasswordFormat')

    yield from app.userService.gChangePassword(@state.user._id, req.oldPassword, req.newPassword)

    # 清cookies
    exports.clearUserSessionCookies(this, app)

    @status = 204

# 通过手机/email重置密码
# phone/email, password, securityCode
exports.gResetPassword = ->
    app = @state.app
    req = @request.body

    unless checkPasswordFormat(req.password, app.config.passwordFormat)
        throw new errors.UserError('BadPasswordFormat')

    if req.phone?
        app.securityCodeService.check(req.phone, req.securityCode)
        yield from app.userService.gResetPasswordByPhone(req.phone, req.password)
    else if req.email?
        app.securityCodeService.check(req.email, req.securityCode)
        yield from app.userService.gResetPasswordByEmail(req.email, req.password)
    else
        @status = 400

    @status = 204

# 用户修改手机接口
exports.gChangePhone = ->
    app = @state.app
    req = @request.body

    # 检查验证码
    app.securityCodeService.check(req.phone, req.securityCode)

    yield from app.userService.gChangePhone(@state.user._id, req.phone)

    @status = 204

# 用户修改 Email
exports.gChangeEmail = ->
    req = @request.body

    # 检查验证码
    app.securityCodeService.check(req.email, req.securityCode)

    yield from app.userService.gChangeEmail(@state.user._id, req.email)

    @status = 204

