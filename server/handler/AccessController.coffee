log = require '../log'
error = require '../error'

UserService = require '../security/UserService'

exports.gIdentifyUser = (next)->
    trackId = @cookies.get(appName + 'TID', {signed: true})
    @state.trackId = trackId

    userId = @cookies.get(appName + 'UserId', {signed: true})
    userToken = @cookies.get(appName + 'UserToken', {signed: true})

    if userId && userToken
        try
            user = yield from UserService.gAuthToken(userId, userToken)
            # log.debug 'auth token: ', user
            @state.user = user if user
        catch e
            false

    yield next

exports.gControlAccess = (next)->
    pass = yield from gCheckAll @
    unless pass
        if @state.user?
            throw new error.Error403()
        else
            throw new error.Error401()

    yield next

gCheckAll = (httpCtx)->
    route = httpCtx.route
    state = httpCtx.state

    ri = route.info
    return true unless ri.auth || ri.action # 明确表示不需要登录直接返回 true

    return true if state.user?.admin # admin 跳过一切权限

    if ri.action
        # 有固定权限的
        yield from gCheckUserHasAction state.user, ri.action
    else if ri.auth is true
        # 只要登录即可，无权限
        state.user?
    else
        gAuthHandler = authHandlers[ri.auth]
        unless gAuthHandler
            log.system.error 'No auth handler for ' + ri.auth
            return false

        yield from gAuthHandler httpCtx

# 检查用户是否有固定权限
gCheckUserHasAction = (user, action)->
    return false unless user?

    return true if user.acl?.action?.has action

    roles = user.roles
    if roles
        for roleId in roles
            role = yield from UserService.gRoleById roleId
            return true if role?.acl?.action?.as action

    false

authHandlers =
    listEntity: (httpCtx)->
        yield from gCheckUserHasEntityAction httpCtx.state.user, 'List', httpCtx.params.entityName
    getEntity: (httpCtx)->
        yield from gCheckUserHasEntityAction httpCtx.state.user, 'Get', httpCtx.params.entityName
    createEntity: (httpCtx)->
        yield from gCheckUserHasEntityAction httpCtx.state.user, 'Create', httpCtx.params.entityName
    updateOneEntity: (httpCtx)->
        yield from gCheckUserHasEntityAction httpCtx.state.user, 'UpdateOne', httpCtx.params.entityName
    updateManyEntity: (httpCtx)->
        yield from gCheckUserHasEntityAction httpCtx.state.user, 'UpdateMany', httpCtx.params.entityName
    removeEntity: (httpCtx)->
        yield from gCheckUserHasEntityAction httpCtx.state.user, 'Remove', httpCtx.params.entityName
    recoverEntity: (httpCtx)->
        yield from gCheckUserHasEntityAction httpCtx.state.user, 'Recover', httpCtx.params.entityName

gCheckUserHasEntityAction = (user, action, entityName)->
    if user?
        entityAcl = user.acl?.entity?[entityName]
        return true if '*' in entityAcl || action in entityAcl

        roles = user.roles
        if roles
            for roleId in roles
                role = yield from UserService.gRoleById roleId
                if role
                    entityAcl = role.acl?.entity?[entityName]
                    return true if '*' in entityAcl || action in entityAcl
    else
        role = yield from UserService.gGetAnonymousRole()
        if role
            entityAcl = role.acl?.entity?[entityName]
            return true if '*' in entityAcl || action in entityAcl
    false
