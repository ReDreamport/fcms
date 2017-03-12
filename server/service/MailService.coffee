nodemailer = require 'nodemailer'
Promise = require 'bluebird'

class MailService
    constructor: (@app)->
        @pTransporterSendMail = null
        @mailConfig = @app.config.mail

        transporter = nodemailer.createTransport
            host: @mailConfig.host,
            port: @mailConfig.port,
            auth:
                user: @mailConfig.user,
                pass: @mailConfig.password

        @_pSendMail = Promise.promisify transporter.sendMail.bind(transporter)

    gSendEmail: (to, subject, content)->
        mailOptions = {from: @mailConfig.user, to, subject, text: content}
        yield @_pSendMail mailOptions

exports.MailService = MailService