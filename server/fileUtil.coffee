fs = require 'fs'
path = require 'path'
Promise = require 'bluebird'

pMakeDir = Promise.promisify require('mkdirp')

exports.pUnlink = Promise.promisify fs.unlink

pRename = Promise.promisify fs.rename

pStat = Promise.promisify fs.stat

log = require './log'

exports.gMoveFileTo = (oldName, newName)->
    targetDir = path.dirname(newName)
    try
        stats = yield pStat targetDir
    catch e
        log.system.error e, 'pStat'
    yield pMakeDir targetDir unless stats?.isDirectory()

    yield pRename oldName, newName

exports.gFileExists = (fileFullPath)->
    try
        yield pStat fileFullPath
        return true
    catch e
        return false if e.code == 'ENOENT'
        throw e