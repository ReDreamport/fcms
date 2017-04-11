config = require '../config'

jadeLocals = {}
exports.jadeLocals = jadeLocals

Jade = require 'koa-jade'
jade = new Jade({viewPath: config.serverJadePath, locals: jadeLocals, noCache: process.env.DEV == '1'})
exports.jade = jade