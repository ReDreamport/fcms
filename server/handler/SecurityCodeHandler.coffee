CaptchaHandler = require './CaptchaHandler'
error = require '../error'

# 发送验证码到手机
exports.gSendSignUpCodeToPhone = ->
    app = @state.app
    captchaId = @request.body?.captchaId || @cookies.get('captcha_id', {signed: true})
    captchaText = @request.body?.captchaText

    throw new error.UserError('CaptchaWrong') unless captchaId and captchaText

    unless CaptchaHandler.check(captchaId, captchaText)
        CaptchaHandler.clearById(captchaId)
        throw new error.UserError('CaptchaWrong')

    # 现在是不管验证码是否输入正确了一律只能用一次的策略
    CaptchaHandler.clearById(captchaId)

    phone = @params.phone
    return @status = 400 unless phone
    yield from app.securityCodeService.gSendSecurityCodeToPhone(phone, app.config.signUpMessage)

    @status = 204

# 发送验证码到邮箱
exports.gSendSignUpCodeToEmail = ->
    app = @state.app
    captchaId = @request.body?.captchaId || @cookies.get('captcha_id', {signed: true})
    captchaText = @request.body?.captchaText

    throw new error.UserError('CaptchaWrong') unless captchaId and captchaText

    unless CaptchaHandler.check(captchaId, captchaText)
        CaptchaHandler.clearById(captchaId)
        throw new error.UserError('CaptchaWrong')

    # 现在是不管验证码是否输入正确了一律只能用一次的策略
    CaptchaHandler.clearById(captchaId)

    email = @params.email
    return @status = 400 unless email

    message = app.config.signUpMessage
    yield from app.securityCodeService.gSendSecurityCodeToEmail(email, message, message)
    @status = 204




