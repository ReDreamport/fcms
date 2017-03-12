config = require './config'
log = require './log'

rootApp = null
apps = {}
exports.apps = apps

Application = require('./Application').Application

exports.gInit = ->
    moment = require 'moment'
    moment.locale "zh-cn"

    yield from gCreateApps()

    for name, app of apps
        yield from app.gInit()
        log.system.info "Application [#{name}] started"

exports.getAppByName = (name)-> apps[name]

exports.gDispose = ->
    for name, app of apps
        yield from app.gDispose()

gCreateApps = ->
    fs = require('fs')
    Promise = require 'bluebird'
    pReadDir = Promise.promisify fs.readdir.bind(fs)

    appsDir = __dirname + "/apps"
    files = yield pReadDir appsDir
    for dir in files
        dirPath = appsDir + "/" + dir
        App = require(dirPath).Application
        app = new App()
        apps[app.name] = app
        rootApp = app if app.name == 'root'

        log.system.info "Application [#{app.name}] created"
