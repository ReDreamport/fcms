exports.serverPort = 7090
exports.cookieKey = ""
exports.serverJadePath = ""
exports.uploadPath = ""
exports.httpBodyMaxFieldsSize = 6 * 1024 * 1024

exports.sessionExpireAtServer = 1000 * 60 * 60 * 24 * 15; #  15 day
exports.usernameFields = ['username']

exports.mongo = {url: ''}

exports.mysql = null

exports.mail = null

exports.passwordFormat = /^([a-zA-Z0-9]){8,20}$/

exports.emailOrg = ''

exports.fileDir = ''

exports.urlPrefix = null

exports.errorCatcher = null

exports.fileDownloadPrefix = '/r/'