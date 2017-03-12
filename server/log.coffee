bunyan = require('bunyan')

exports.debug = true # TODO 远程开关

system = bunyan.createLogger({name: "system", level: "trace"})
exports.system = system

exports.debug = -> system.debug.apply system, arguments

class Log
    constructor: (@app)->
        @system = bunyan.createLogger(@app.config.log?.system || {name: "#{@app.name}-system", level: "trace"})

    debug: -> @system.debug.apply @system, arguments

exports.Log = Log
