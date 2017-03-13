exports.Actions = {
    Create: 'Create',
    Update: 'Update',
    Remove: "Remove",
    Recover: "Recover"
}

defaultInterceptor = (args...)-> yield from args[args.length - 1]()

interceptors = {}

exports.setInterceptor = (entityName, actions, gInterceptor)->
    interceptors[entityName] = interceptors[entityName] ? {}
    for action in actions
        interceptors[entityName][action] = gInterceptor

exports.getInterceptor = (entityName, action)->
    interceptors[entityName]?[action] || defaultInterceptor
