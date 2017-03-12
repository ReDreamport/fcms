chance = new require('chance')()
Promise = require 'bluebird'
request = require 'request'
requestPost = Promise.promisify request.post.bind(request)

error = require '../error'

class SecurityCodeService
    constructor: (@app)->
        @securityCodes = {}

    # 验证验证码
    check: (target, code)->
        expectedCode = @securityCodes[target]
        unless expectedCode? && expectedCode.code == code
            throw new error.UserError("SecurityCodeNotMatch")
        if new Date().getTime() - expectedCode.sendTime > 15 * 60 * 1000
            throw new error.UserError("SecurityCodeExpired") # 过期

        delete @securityCodes[target]

    # 发送验证码到邮箱
    gSendSecurityCodeToEmail: (toEmail, subject, purpose)->
        code = @_generateSecurityCode(toEmail)
        mailService = @app.mailService
        throw new error.SystemError 'NoMailService', '无发信机制' unless mailService?

        yield from mailService.gSendEmail(toEmail, subject, "#{purpose}。您本次操作的验证码是 #{code}。")

    # TODO 发送验证码到手机
    gSendSecurityCodeToPhone: (phone, purpose)->
        code = @_generateSecurityCode(phone)

        message = new Buffer("@1@=#{purpose},@2@=#{code}", 'utf8').toString('utf8')

        postData =
            method: "sendUtf8Msg"
            username: config.sms.username
            password: config.sms.password
            veryCode: config.sms.veryCode
            mobile: phone
            content: message,
            msgtype: 2
            tempid: config.sms.template,
            code: "utf-8"

        r = yield requestPost config.sms.url, {
            form: postData,
            headers: {'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8'}
        }
        return r.body?.match('<status>0</status>')?.length > 0

    _generateSecurityCode: (address) ->
        code = chance.string length: 6, pool: '0123456789'
        @securityCodes[address] = {code: code, sendTime: new Date().getTime()}
        code

exports.SecurityCodeService = SecurityCodeService