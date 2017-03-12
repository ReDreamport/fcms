table = {}

chance = new require('chance')()
simpleCaptcha = require('simple-captcha')

exports.generate = (next)->
    captcha = simpleCaptcha.create({width: 100, height: 40})
    text = captcha.text()
    captcha.generate()

    id = chance.hash()
    @cookies.set('captcha_id', id, {signed: true, httpOnly: true})
    table[id] = text

    @set 'X-Captcha-Id', id
    @body = captcha.buffer('image/png')
    @type = 'image/png'
    yield next

exports.check = (id, text)-> id? and text? and table[id] and table[id] == text

exports.clearById = (id)-> delete table[id]

