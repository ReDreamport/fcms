config = require './config'
exports.use = (f)->
    if not config.cluster
        f()
    else
        cluster = require('cluster')
        workerNum = config.workerNum

        if cluster.isMaster
            console.log("Master #{process.pid} is running")

            cluster.on 'exit', (worker, code, signal) ->
                console.log "worker #{worker.process.pid} died"

            cluster.fork() for i in [0...workerNum]

        else
            console.log "Start Worker #{process.pid} started"

            f()