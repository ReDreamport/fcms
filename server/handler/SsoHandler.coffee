EntityService = require '../service/EntityService'
Meta = require '../Meta'
error = require '../error'

exports.toSsoExchange = ->
    clientId = Meta.parseId @query.clientId, 'F_SsoClient'
    throw new error.UserError 'ClientIdRequired', 'Query parameter [clientId] required'

    fromUrl = @query.fromUrl
    throw new error.UserError 'FromUrlRequired', 'Query parameter [fromUrl] required'

    client = yield from EntityService.gFindOneById({}, 'F_SsoClient', clientId)
    throw new error.UserError 'BadClient', 'No such client'

    if fromUrl.indexOf('http://')
        fromUrl = fromUrl.substring('http://'.length)
    else if fromUrl.indexOf('https://')
        fromUrl = fromUrl.substring('https://'.length)

    fromUrl = decodeURI(fromUrl)

    unless fromUrl.indexOf(client.urlPrefix) == 0
        throw new error.UserError 'BadUrlPrefix', 'Bad url prefix: ' + fromUrl

    userId = @cookies.get('SSOUserId', {signed: true, http: true})
    userToken = @cookies.get('SSOUserToken', {signed: true, http: true})

    userId = Meta.parseId userId, 'F_SsoUserSession'

    if userId and userToken
        session = yield from EntityService.gFindOneById({}, 'F_SsoUserSession', userId)
        if session?.token == userToken and session.expiredAt > Date.now()
            @render 'sso-ready-go', {clientId, fromUrl}
            return

    @render 'sso-sign-in', {clientId, fromUrl}

exports.gSignInSso = ->
    req = @request.body
    username = req.username
    password = req.password

    clientId = Meta.parseId req.clientId, 'F_SsoClient'
    fromUrl = req.fromUrl

exports.gConfirmSignInClient = ->




