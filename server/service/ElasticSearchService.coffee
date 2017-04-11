request = require('request')
Promise = require('bluebird')
pRequest = Promise.promisify(request)
co = require 'co'

_ = require 'lodash'

config = require '../config'
log = require '../log'

exports.gConfigElasticSearch = (req)->
    url = config.elasticSearchEndpoint + encodeURI(req.path)
    # log.debug 'url', url

    yield pRequest {url: url, method: req.method, json: req.body}

exports.gIndexDocuments = (index, type, documents)->
    req = []
    for doc in documents
        req.push JSON.stringify {"index": {"_index": index, "_type": type, "_id": doc._id}}
        doc = _.clone(doc)
        delete doc._id
        req.push JSON.stringify doc

    url = config.elasticSearchEndpoint + "_bulk"
    res = yield pRequest {url: url, method: 'POST', body: req.join("\n")}

    # resBody = JSON.parse(res.body)
    # log.debug 'gIndexDocuments', res.statusCode, resBody.errors
    # log.debug 'items:', resBody.items

    unless res.statusCode == 200
        throw new Error 'gIndexDocuments fails ' + res.statusCode

exports.gIndexDocument = (index, type, id, doc)->
    url = config.elasticSearchEndpoint + "#{index}/#{type}/#{id}"

    res = yield pRequest {url: url, method: 'PUT', json: doc}
    unless res.statusCode == 200 || res.statusCode == 201
        log.system.error res.body, 'gIndexDocument'
        throw new Error 'gIndexDocument fails ' + res.statusCode

exports.gRemoveDocument = (index, type, id)->
    url = config.elasticSearchEndpoint + "#{index}/#{type}/#{id}"
    res = yield pRequest {url: url, method: 'DELETE'}
    unless res.statusCode == 200 || res.statusCode == 204
        throw new Error 'gRemoveDocument fails ' + res.statusCode
    else
        log.system.info "gRemoveDocument #{index}/#{type} #{id}"

exports.removeDocumentAsync = (index, type, id)->
    co(->
        yield from exports.gRemoveDocument(index, type, id)
    ).catch (e)->
        log.system.error e, "removeDocumentAsync #{index}/#{type}"

exports.gRemoveAllDocuments = (index)->
    url = config.elasticSearchEndpoint + "#{index}/_delete_by_query"
    query = {query: {match_all: {}}}
    res = yield pRequest {url: url, method: 'POST', json: query}

    log.debug 'res', res.body

    unless res.statusCode == 200
        throw new Error 'gRemoveAll fails ' + res.statusCode

test2 = ->
    yield from exports.gRemoveAllDocuments('game')





