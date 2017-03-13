Meta = require '../Meta'
log = require '../log'

exports.gSyncWithMeta = (mysql)->
    entities = Meta.getAllMeta().entities

    for entityName, entityMeta of entities
        continue unless entityMeta.db == Meta.DB.mysql
        try
            tableName = entityMeta.tableName
            currentIndexes = entityMeta.mysqlIndexes || []

            yield from mysql.gWithTransaction (conn)->
                r = yield conn.pRead 'show index from ' + tableName
                existedIndexNames = (i.Key_name.toLowerCase() for i in r)

                # 创建索引
                for i in currentIndexes
                    continue if i.toLowerCase() in existedIndexNames

                    fieldsArray = i.fields.split(",")
                    fields = []
                    for f in fieldsArray
                        fc = f.split(":")
                        fields.push(mysql.escapeId(fc[0]) + " " + (parseInt(fc[1], 10) > 0 && "ASC" || "DESC"))
                    fields = fields.join(", ")

                    unique = i.unique && 'UNIQUE' || ''
                    indexType = i.indexType && i.indexType || ''
                    sql = "create #{unique} index #{mysql.escapeId(i.name)} #{indexType} on #{mysql.escapeId(tableName)}(#{fields})"
                    yield conn.pWrite(sql)

        # TODO 删除不再需要的索引
        # 小心不要删除主键！！
        catch e
            log.system.error e, entityName