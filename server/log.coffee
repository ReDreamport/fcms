bunyan = require('bunyan')

exports.debug = true # TODO 远程开关

exports.config = (config)->
    exports.system = bunyan.createLogger(config.log?.system || {name: "system", level: "trace"})
    exports.debug = -> exports.system.debug.apply exports.system, arguments
