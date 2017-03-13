nodemailer = require 'nodemailer'
Promise = require 'bluebird'

config = require '../config'

exports.gSendEmail = (to, subject, content)->
    throw new Error '无发信机制' unless config.mail?
    mailOptions = {from: config.mail.user, to, subject, text: content}
    pSendMail = prepareSender()
    yield pSendMail mailOptions

pSendMail = null
prepareSender = ->
    return pSendMail if pSendMail?

    transporter = nodemailer.createTransport
        host: config.mail.host,
        port: config.mail.port,
        auth:
            user: config.mail.user,
            pass: config.mail.password
    pSendMail = Promise.promisify transporter.sendMail.bind(transporter)
    pSendMail
