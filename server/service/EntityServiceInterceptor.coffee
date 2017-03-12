Actions = {
    Create: 'Create',
    Update: 'Update',
    Remove: "Remove",
    Recover: "Recover"
}
exports.Actions = Actions

defaultInterceptor = (args...)-> yield from args[args.length - 1]()

class EntityServiceInterceptor
    constructor: (@app)->
        @interceptors = {}

    setInterceptor: (entityName, actions, gInterceptor)->
        @interceptors[entityName] = @interceptors[entityName] ? {}
        for action in actions
            @interceptors[entityName][action] = gInterceptor

    getInterceptor: (entityName, action)->
        @interceptors[entityName]?[action] || defaultInterceptor

exports.EntityServiceInterceptor = EntityServiceInterceptor