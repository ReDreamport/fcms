chance = new require('chance')()

Cache = require '../cache/Cache'

exports.gGenerate = (next)->
    simpleCaptcha = require('simple-captcha')
    captcha = simpleCaptcha.create({width: 100, height: 40})
    text = captcha.text()
    captcha.generate()

    id = chance.hash()
    @cookies.set('captcha_id', id, {signed: true, httpOnly: true})
    yield from Cache.gSetString ['captcha', id], text

    @set 'X-Captcha-Id', id
    @body = captcha.buffer('image/png')
    @type = 'image/png'

exports.gCheck = (id, text)->
    return false unless id? and text?
    expected = yield from Cache.gGetString ['captcha', id]
    expected == text

exports.gClearById = (id)-> yield from Cache.gUnset ['captcha'], [id]

