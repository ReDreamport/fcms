Meta = require '../Meta'
log = require '../log'

# 在执行数据库创建指定实体的元数据
exports.gSyncWithMeta = (mongo)->
    db = yield from mongo.gDatabase()

    entities = Meta.getEntities()

    for entityName, entityMeta of entities
        continue unless entityMeta.db == Meta.DB.mongo
        try
            tableName = entityMeta.tableName
            c = db.collection tableName

            currentIndexes = entityMeta.mongoIndexes || []
            # 创建索引
            for i in currentIndexes
                fieldsArray = i.fields.split(",")
                fields = {}
                for f in fieldsArray
                    fc = f.split(":")
                    fields[fc[0]] = parseInt(fc[1], 10)
                options = {name: tableName + "_" + i.name}
                options.unique = true if i.unique
                options.sparse = true if i.sparse

                yield c.createIndex(fields, options)

        # TODO 删除不再需要的索引
        # 小心不要删除主键！！
        # existedIndexes = yield c.listIndexes().toArray()
        catch e
            log.system.error e, 'create mongo index', entityName