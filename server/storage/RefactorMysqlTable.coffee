Meta = require '../Meta'
log = require '../log'

exports.gSyncSchema = (mysql)->
    entities = Meta.getEntities()

    for entityName, entityMeta of entities
        continue unless entityMeta.db == Meta.DB.mysql

        # 创建 Schema 貌似是自动提交的
        yield from mysql.gWithoutTransaction (conn)->
            unless yield from gTableExists(entityMeta.tableName, conn)
                log.system.info 'create table for ' + entityName
                yield from gCreateTable(entityMeta, conn)
            else
                for fieldName, fieldMeta of entityMeta.fields
                    unless yield from gColumnExists(entityMeta.tableName, fieldName, conn)
                        log.system.info 'add column ' + fieldName + ' for ' + entityName
                        yield from gAddColumn(entityMeta, fieldMeta, conn)

gCreateTable = (entityMeta, conn)->
    sql = "CREATE TABLE ?? ("
    columns = []
    args = [entityMeta.tableName]

    for fieldName, fieldMeta of entityMeta.fields
        sqlType = if fieldMeta.sqlColM
            "#{fieldMeta.persistType}(#{fieldMeta.sqlColM})"
        else
            fieldMeta.persistType
        notNull = fieldMeta.required && "NOT NULL" || "NULL"
        columns.push "?? #{sqlType} #{notNull}"
        args.push fieldName

    sql = sql + columns.join(", ") + ", PRIMARY KEY (`_id`))"
    # log.debug 'sql', sql, args

    yield conn.pWrite sql, args

gRenameTable = (oldName, newName, conn)->
    yield conn.pWrite "alter table ?? rename ??", [oldName, newName]

gDropTable = (name, conn)->
    yield conn.pWrite "drop table ??", [name]

gAddColumn = (entityMeta, fieldMeta, conn)->
    sql = "ALTER TABLE ?? Add Column ?? "
    args = [entityMeta.tableName, fieldName]

    sqlType = if fieldMeta.sqlColM
        "#{fieldMeta.persistType}(#{fieldMeta.sqlColM})"
    else
        fieldMeta.persistType
    notNull = fieldMeta.required && "NOT NULL" || ""
    sql += "#{sqlType} #{notNull}"

    yield conn.pWrite sql, args

gTableExists = (tableName, conn)->
    r = yield conn.pRead "SHOW TABLES LIKE ?", [tableName]
    # log.debug 'gTableExists', tableName, r
    r?.length

gColumnExists = (tableName, columnName, conn)->
    r = yield conn.pRead "SHOW COLUMNS FROM ?? LIKE ?", [tableName, columnName]
    r?.length