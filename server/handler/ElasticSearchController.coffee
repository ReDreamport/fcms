_ = require 'lodash'

ElasticSearchService = require '../service/ElasticSearchService'

exports.gConfig = ->
    req = @request.body
    return @status = 400 unless req

    res = yield from ElasticSearchService.gConfig(req)

    @body = {
        status: res.statusCode
        body: _.isString(res.body) && JSON.parse(res.body) || res.body
    }