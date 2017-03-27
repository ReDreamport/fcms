Promise = require 'bluebird'
_ = require 'lodash'
mysql = require 'mysql'
PoolConnection = require 'mysql/lib/PoolConnection'

log = require '../log'
config = require '../config'

class MysqlStore
    constructor: (@config)->

    _init: ->
        @pool = mysql.createPool
            connectionLimit: 3
            host: @config.host
            user: @config.user
            password: @config.password
            database: @config.database

        @pConnection = Promise.promisify pool.getConnection.bind(pool)

    gDispose: ->
        return unless @pool?

        log.system.info "Closing mysql [#{@config.host}]..."

        pEndPool = Promise.promisify @pool.end.bind(@pool)
        try
            yield pEndPool()
        catch
            log.system.error e, 'dispose mysql', @config.host +"/" + @config.database

    gConnect: ->
        @_init() unless @pool?

        connection = yield @pConnection()
        new MysqlConnection(connection)

    gWithTransaction: (gWork)->
        conn = yield from @gConnect()

        try
            yield conn.pBeginTransaction()
            r = yield from gWork(conn)
            yield conn.pCommit()
            return r
        catch e
            try
                yield conn.pRollback()
            catch e2
                log.system.error e2, "autoCommit, rollback"
            throw e
        finally
            conn.release()

    gWithoutTransaction: (gWork)->
        conn = yield from @gConnect()

        try
            yield from gWork(conn)
        finally
            conn.release()

    gReuseTransaction: (ctx, gWork)->
        unless ctx.conn?
            yield from @gWithTransaction (conn)->
                ctx.conn = conn

        yield from gWork ctx.conn

class MysqlConnection
    constructor: (@conn)->
        @pQuery = Promise.promisify @conn.query.bind(@conn)
        @pBeginTransaction = Promise.promisify @conn.beginTransaction.bind(@conn)
        @pCommit = Promise.promisify @conn.commit.bind(@conn)
        @pRollback = Promise.promisify @conn.rollback.bind(@conn)
        @pRead = @pQuery

    release: -> @conn.release()

    pWrite: ->
        @written = true
        @pQuery.apply @conn, arguments

    gFind: ({table, criteria, includedFields, sort, pageNo, pageSize, paging})->
        values = []
        select = '*'
        where = ''
        orderBy = ''
        skipLimit = ''

        if includedFields
            # 需要加上在 where 子句中出现的列
            criteriaFields = listCriteriaFields criteria
            includedFields = _.uniqu(_.concat(includedFields, criteriaFields))
            select = arrayToSelectClause includedFields

        if criteria and _.size(criteria)
            _w = criteriaToWhereClause(criteria, values)
            where = "WHERE " + _w if _w

        if sort
            orderBy = "ORDER BY " + objectToOrderClause(sort)

        if pageSize > 0
            pageNo = 1 if pageNo < 1
            skipLimit = "SKIP #{(pageNo - 1) * pageSize} LIMIT #{pageSize}"

        sql = "select #{select} from #{table} #{where} #{orderBy} #{skipLimit}"
        list = yield @pRead(sql, values)

        unless paging
            list
        else
            sql = "select COUNT(1) as count from #{table} #{where}"
            r = yield @pRead(sql, values)
            {total: r[0].count, page: list}

    gListByIds: (table, ids)->
        return [] unless ids?.length

        sqlValues = []
        inClause = buildInClause(ids, sqlValues)
        return [] unless inClause

        sql = "select * from #{table} where _id IN #{inClause}"
        yield @pRead(sql, sqlValues)

    gInsertOne: (table, object, keys)->
        yield from @gInsertMany table, [object], keys

    gInsertMany: (table, objects, keys)->
        return null unless objects?.length
        unless keys?.length
            keys = _.keys(objects[0])
        return null unless keys?.length

        columns = (mysql.escapeId(key) for key in keys)

        placeholders = []
        sqlValues = []
        for object in objects
            placeholders2 = []
            for key in keys
                placeholders2.push '?'
                sqlValues.push object[key]
            placeholders.push "(#{placeholders2.join(',')})"

        sql = "insert into #{table}(#{columns.join(',')}) values #{placeholders.join(',')}"
        log.debug "sql,values", sql, sqlValues
        yield @pWrite(sql, sqlValues)

    gUpdateByCriteria: (table, criteria, patch)->
        return null unless _.size(criteria)
        return null unless _.size(patch)

        sqlValues = []
        set = objectToSetClause(patch, sqlValues)
        where = criteriaToWhereClause(criteria, sqlValues)

        sql = "update #{table} set #{set} where #{where}"
        log.debug "sql,values", sql, sqlValues
        yield @pWrite(sql, sqlValues)

    gDeleteManyByIds: (table, ids)->
        return unless ids?.length

        sqlValues = []
        inClause = buildInClause ids, sqlValues
        sql = "delete * from #{table} where _id IN #{inClause}"
        yield @pWrite(sql, sqlValues)

exports.init = ->
    mysqlConfig = config.mysql
    if mysqlConfig
        exports.mysql = new MysqlStore mysqlConfig

exports.gDispose = ->
    yield from exports.mysql.gDispose() if exports.mysql

exports.isIndexConflictError = (e)-> e.code == 'ER_DUP_ENTRY'

arrayToSelectClause = (array)->
    fields = (mysql.escapeId(f) for f in array)
    fields.join(',')

criteriaToWhereClause = (criteria, sqlValues)->
    __type = criteria.__type
    delete criteria.__type

    switch __type
        when 'mongo'
            throw new Error 'Cannot use mongo criteria for mysql'
        when 'relation'
            relationCriteriaToWhereClause criteria, sqlValues
        else
            objectToWhereClause criteria, sqlValues

objectToWhereClause = (object, values)->
    conditions = []
    for key, value of object
        conditions.push "#{mysql.escapeId(key)} = ?"
        values.push value
    conditions.join ' AND '

relationCriteriaToWhereClause = (criteria, sqlValues)->
    if criteria.relation
        items = []
        for item in criteria.items
            i = relationCriteriaToWhereClause item, sqlValues
            items.push i if i
        return null unless items.length
        if criteria.relation == 'or'
            "(" + items.join(" OR ") + ")"
        else
            items.join(" AND ")
    else if criteria.field
        operator = criteria.operator
        comparedValue = criteria.value
        field = mysql.escapeId(criteria.field)
        switch operator
            when '=='
                sqlValues.push comparedValue # TODO 对于部分运算符要检查 comparedValue 不为 null/undefined/NaN
                field + " = ?"
            when '!='
                sqlValues.push comparedValue
                field + " <> ?"
            when '>'
                sqlValues.push comparedValue
                field + " > ?"
            when '>='
                sqlValues.push comparedValue
                field + " >= ?"
            when '<'
                sqlValues.push comparedValue
                field + " < ?"
            when '<='
                sqlValues.push comparedValue
                field + " <= ?"
            when 'in'
                field + " IN " + buildInClause(comparedValue, sqlValues)
            when 'nin'
                field + " NOT IN " + buildInClause(comparedValue, sqlValues)
            when 'start'
                sqlValues.push(comparedValue + "%")
                field + " LIKE ?"
            when 'end'
                sqlValues.push("%" + comparedValue)
                field + " LIKE ?"
            when 'contain'
                sqlValues.push("%" + comparedValue + "%")
                field + " LIKE ?"
            else
                null

buildInClause = (inList, sqlValues)->
    return "" unless inList?.length
    placeholders = []
    for i in inList
        placeholders.push "?"
        sqlValues.push i
    "(" + placeholders.join(',') + ")"

objectToOrderClause = (object)->
    orders = []
    for key, value of object
        orders.push mysql.escapeId(key) + " " + (value < 0 && "DESC" || "ASC")
    orders.join(',')

objectToSetClause = (object, values)->
    set = []
    for key, value of object
        set.push "#{mysql.escapeId(key)} = ?"
        values.push value
    set.join(',')

_listCriteriaFields = (criteria, list)->
    if criteria.relation
        for item in criteria.items
            _listCriteriaFields(criteria, list)
    else if criteria.field
        list.push criteria.field

listCriteriaFields = (criteria)->
    list = []
    _listCriteriaFields(criteria, list)
    _.uniq(list)