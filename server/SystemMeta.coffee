_ = require 'lodash'

Meta = require './Meta'

patchSystemFields = (entityMeta)->
    fields = {}
    dbType = entityMeta.db

    idType = entityMeta.idType || (if dbType == Meta.DB.mongo then 'ObjectId' else 'String')
    idPersistType = if dbType == Meta.DB.mongo
        if idType == 'ObjectId' then 'ObjectId' else 'String'
    else
        'char'

    intPersistType = dbType == Meta.DB.mongo && 'Number' || 'int'

    timestampPersistType = dbType == Meta.DB.mongo && 'Date' || 'timestamp'

    # 系统的用户ID 均为 24 位字符串，不使用 ObjectId
    userIdPersistType = dbType == Meta.DB.mongo && 'String' || 'char'

    fields._id = {
        system: true, name: "_id", label: "ID", fastFilter: true, required: true
        type: idType, persistType: idPersistType, sqlColM: Meta.ObjectIdStringLength
        inputType: "Text", noCreate: true, noEdit: true
    }
    fields._version = {
        system: true, name: "_version", label: "修改版本",
        type: "Int", persistType: intPersistType, sqlColM: 12
        inputType: "Int", noCreate: true, noEdit: true, hideInListPage: true
    }
    fields._createdOn = {
        system: true, name: "_createdOn", label: "创建时间",
        type: "DateTime", persistType: timestampPersistType
        inputType: "DateTime", noCreate: true, noEdit: true
    }
    fields._modifiedOn = {
        system: true, name: "_modifiedOn", label: "修改时间",
        type: "DateTime", persistType: timestampPersistType
        inputType: "DateTime", noCreate: true, noEdit: true
    }
    fields._createdBy = {
        system: true, name: "_createdBy", label: "创建人",
        type: "Reference", refEntity: 'F_User', persistType: userIdPersistType, sqlColM: Meta.ObjectIdStringLength
        inputType: "Reference", noCreate: true, noEdit: true, hideInListPage: true
    }
    fields._modifiedBy = {
        system: true, name: "_modifiedBy", label: "修改人",
        type: "Reference", refEntity: 'F_User', persistType: userIdPersistType, sqlColM: Meta.ObjectIdStringLength
        inputType: "Reference", noCreate: true, noEdit: true, hideInListPage: true
    }

    entityMeta.fields = _.assign(fields, entityMeta.fields)

exports.patchSystemFields = patchSystemFields

arrayToOption = (a)-> {name: i, label: i} for i in a

SystemEntities = {
    F_EntityMeta: {
        system: true,
        name: 'F_EntityMeta', label: '实体元数据'
        db: Meta.DB.none
        fields:
            system:
                name: 'system', label: '系统实体', type: 'Boolean', inputType: "Check", noCreate: true, noEdit: true
            name:
                name: 'name', label: '名称', type: 'String', inputType: "Text"
            label:
                name: 'label', label: '显示名', type: 'String', inputType: "Text"
            db:
                name: 'db', label: '数据库', type: 'String', inputType: "Select"
                options: [{name: Meta.DB.mongo, label: 'MongoDB'}, {name: Meta.DB.mysql, label: 'MySQL'},
                    {name: Meta.DB.none, label: '不使用数据库'}]
            tableName:
                name: 'tableName', label: '表名', type: 'String', inputType: "Text"
            noCreate:
                name: 'noCreate', label: '禁止新增', type: 'Boolean', inputType: "Check"
            noEdit:
                name: 'noEdit', label: '禁止编辑', type: 'Boolean', inputType: "Check"
            noDelete:
                name: 'noDelete', label: '禁止删除', type: 'Boolean', inputType: "Check"
            entityNumMin:
                name: 'entityNumMin', label: '实体数量下限', type: 'Int', inputType: "Int"
            entityNumMax:
                name: 'entityNumMax', label: '实体数量上限', type: 'Int', inputType: "Int"
            digestFields:
                name: 'digestFields', label: '摘要字段', type: 'String', inputType: "Text"
            mongoIndexes:
                name: 'mongoIndexes', label: 'MongoDB索引', type: 'Component', refEntity: "F_MongoIndex",
                inputType: "PopupComponent", multiple: true
            mysqlIndexes:
                name: 'mysqlIndexes', label: 'MySQL索引', type: 'Component', refEntity: "F_MySQLIndex",
                inputType: "PopupComponent", multiple: true
            editEnhanceFunc:
                name: 'editEnhanceFunc', label: '编辑增强脚本', type: 'String', inputType: "Text"
                hideInListPage: true
            fields:
                name: 'fields', label: '字段列表', type: 'Component', refEntity: "F_FieldMeta", inputType: "PopupComponent",
                multiple: true
    }
    F_FieldMeta: {
        system: true, noPatchSystemFields: true
        name: 'F_FieldMeta', label: '字段元数据'
        db: Meta.DB.none
        digestFields: 'name,label,type,multiple'
        editEnhanceFunc: 'F.enhanceFieldMetaEdit'
        fields:
            system:
                name: 'system', label: '系统字段', type: 'Boolean', inputType: "Check", noCreate: true, noEdit: true
                hideInListPage: true
            name:
                name: 'name', label: '字段名', type: 'String', inputType: "Text"
            label:
                name: 'label', label: '显示名', type: 'String', inputType: "Text"
            comment:
                name: 'comment', label: '开发备注', type: 'String', inputType: "TextArea"
                hideInListPage: true
            useGuide:
                name: 'useGuide', label: '使用备注', type: 'String', inputType: "Text"
                hideInListPage: true
            type:
                name: 'type', label: '类型', type: 'String', inputType: "Select"
                options: arrayToOption(Meta.FieldDataTypes)
            unique:
                name: 'unique', label: '值唯一', type: 'Boolean', inputType: "Check"
                hideInListPage: true
            refEntity:
                name: 'refEntity', label: '关联实体', type: 'String', inputType: "Text"
            inputType:
                name: 'inputType', label: '输入类型', type: 'String', inputType: "Select"
                optionsDependOnField: 'type', optionsFunc: 'F.optionsOfInputType', hideInListPage: true
            inputFunc:
                name: 'inputFunc', label: '输入构建器', type: 'String', inputType: "Text", hideInListPage: true
            inputRequired:
                name: 'inputRequired', label: '输入值不能为空', type: 'Boolean', inputType: "Check"
                hideInListPage: true
            notShow:
                name: 'notShow', label: '界面隐藏', type: 'Boolean', inputType: "Check"
                hideInListPage: true
            noCreate:
                name: 'noCreate', label: '不允许创建', type: 'Boolean', inputType: "Check"
                hideInListPage: true
            noEdit:
                name: 'noEdit', label: '不允许编辑', type: 'Boolean', inputType: "Check"
                hideInListPage: true
            hideInListPage:
                name: 'hideInListPage', label: '列表页面不显示', type: 'Boolean', inputType: "Check"
                hideInListPage: true
            persistType:
                name: 'persistType', label: '存储类型', type: 'String', inputType: "Select",
                optionsDependOnField: 'type', optionsFunc: 'F.optionsOfPersistType', hideInListPage: true
            sqlColM:
                name: 'sqlColM', label: 'SQL列宽', type: 'Int', inputType: 'Int', hideInListPage: true
            required:
                name: 'required', label: '存储非空', type: 'Boolean', inputType: "Check", hideInListPage: true
            multiple:
                name: 'multiple', label: '多个值', type: 'Boolean', inputType: "Check"
            multipleUnique:
                name: 'unique', label: '多个值不重复', type: 'Boolean', inputType: "Check"
                hideInListPage: true
            multipleMin:
                name: 'multipleMin', label: '多个值数量下限', type: 'Int', inputType: "Int"
                hideInListPage: true
            multipleMax:
                name: 'multipleMax', label: '多个值数量上限', type: 'Int', inputType: "Int"
                hideInListPage: true
            options:
                name: 'options', label: '输入选项', type: 'Component', refEntity: "F_FieldInputOption",
                multiple: true, inputType: "InlineComponent", hideInListPage: true
            optionsDependOnField:
                name: 'optionsDependOnField', label: '输入选项随此字段改变', type: 'String', inputType: "Text"
                hideInListPage: true
            optionsFunc:
                name: 'optionsFunc', label: '选项决定函数', type: 'String', inputType: "Text"
                hideInListPage: true
            groupedOptions:
                name: 'groupedOptions', label: '分组的输入选项', type: 'Component',
                refEntity: "F_FieldInputGroupedOptions", multiple: true, inputType: "InlineComponent"
                hideInListPage: true
            optionWidth:
                name: 'optionWidth', label: '选项宽度', type: 'Int', inputType: "Int"
                hideInListPage: true
            fileStoreDir:
                name: 'fileStoreDir', label: '文件存储路径', type: 'String', inputType: "Text"
                hideInListPage: true
            removePreviousFile:
                name: 'removePreviousFile', label: '自动删除之前的文件', type: 'Boolean', inputType: "Check"
                hideInListPage: true
            fileMaxSize:
                name: 'fileMaxSize', label: '文件大小限制（字节）', type: 'Int', inputType: "Int"
                hideInListPage: true
            fastSearch:
                name: 'fastSearch', label: '支持快速搜索', type: 'Boolean', inputType: "Check"
    }
    F_FieldInputOption: {
        system: true, noPatchSystemFields: true
        name: 'F_FieldInputOption', label: '字段输入选项'
        db: Meta.DB.none
        digestFields: 'name,label'
        fields:
            name:
                name: 'name', label: '字段名', type: 'String', inputType: "Text"
            label:
                name: 'label', label: '显示名', type: 'String', inputType: "Text"
    }
    F_FieldInputGroupedOptions: {
        system: true, noPatchSystemFields: true
        name: 'F_FieldInputGroupedOptions', label: '字段输入分组选项'
        db: Meta.DB.none
        digestFields: 'key'
        fields:
            key:
                name: 'key', label: '分组键', type: 'String', inputType: "Text"
            options:
                name: 'options', label: '选项列表', type: 'Component', refEntity: "F_FieldInputOption",
                multiple: true, inputType: "InlineComponent"
    }
    F_EntityViewMeta: {
        system: true,
        name: 'F_EntityViewMeta', label: '实体视图元数据'
        fields:
            system:
                name: 'system', label: '系统实体', type: 'Boolean', inputType: "Check", noCreate: true, noEdit: true
            name:
                name: 'name', label: '名称', type: 'String', inputType: "Text"
            label:
                name: 'label', label: '显示名', type: 'String', inputType: "Text"
            backEntity:
                name: 'backEntity', label: '真实体', type: 'String', inputType: "Text"
            noCreate:
                name: 'noCreate', label: '禁止新增', type: 'Boolean', inputType: "Check"
            noEdit:
                name: 'noEdit', label: '禁止编辑', type: 'Boolean', inputType: "Check"
            noDelete:
                name: 'noDelete', label: '禁止删除', type: 'Boolean', inputType: "Check"
            entityNumMin:
                name: 'entityNumMin', label: '实体数量下限', type: 'Int', inputType: "Int"
            entityNumMax:
                name: 'entityNumMax', label: '实体数量上限', type: 'Int', inputType: "Int"
            digestFields:
                name: 'digestFields', label: '摘要字段', type: 'String', inputType: "Text"
            editEnhanceFunc:
                name: 'editEnhanceFunc', label: '编辑增强脚本', type: 'String', inputType: "Text"
                hideInListPage: true
            fields:
                name: 'fields', label: '字段列表', type: 'Component', refEntity: "F_FieldViewMeta",
                inputType: "PopupComponent", multiple: true
    }
    F_FieldViewMeta: {
        system: true, noPatchSystemFields: true
        name: 'F_FieldViewMeta', label: '字段视图元数据'
        digestFields: 'name,label,type,multiple'
        editEnhanceFunc: 'F.emptyFunction'
        fields:
            system:
                name: 'system', label: '系统字段', type: 'Boolean', inputType: "Check", noCreate: true, notEdit: true
                hideInListPage: true
            name:
                name: 'name', label: '字段名', type: 'String', inputType: "Text"
            label:
                name: 'label', label: '显示名', type: 'String', inputType: "Text"
            comment:
                name: 'comment', label: '开发备注', type: 'String', inputType: "TextArea"
                hideInListPage: true
            useGuide:
                name: 'useGuide', label: '使用备注', type: 'String', inputType: "Text"
                hideInListPage: true
            refEntity:
                name: 'refEntity', label: '关联实体', type: 'String', inputType: "Text"
            inputType:
                name: 'inputType', label: '输入类型', type: 'String', inputType: "Select"
                optionsDependOnField: 'type', optionsFunc: 'F.optionsOfInputType', hideInListPage: true
            inputRequired:
                name: 'inputRequired', label: '输入值不能为空', type: 'Boolean', inputType: "Check"
                hideInListPage: true
            noCreate:
                name: 'noCreate', label: '创建时隐藏', type: 'Boolean', inputType: "Check"
                hideInListPage: true
            noEdit:
                name: 'noEdit', label: '编辑时隐藏', type: 'Boolean', inputType: "Check"
                hideInListPage: true
            hideInListPage:
                name: 'hideInListPage', label: '列表页面不显示', type: 'Boolean', inputType: "Check"
                hideInListPage: true
            options:
                name: 'options', label: '输入选项', type: 'Component', refEntity: "F_FieldInputOption",
                multiple: true, inputType: "InlineComponent", hideInListPage: true
            optionsDependOnField:
                name: 'optionsDependOnField', label: '输入选项随此字段改变', type: 'String', inputType: "Text"
                hideInListPage: true
            optionsFunc:
                name: 'optionsFunc', label: '选项决定函数', type: 'String', inputType: "Text"
                hideInListPage: true
            groupedOptions:
                name: 'groupedOptions', label: '分组的输入选项', type: 'Component',
                refEntity: "F_FieldInputGroupedOptions", multiple: true, inputType: "InlineComponent"
                hideInListPage: true
            optionWidth:
                name: 'optionWidth', label: '选项宽度', type: 'Int', inputType: "Int"
                hideInListPage: true
            fileMaxSize:
                name: 'fileMaxSize', label: '文件大小限制（字节）', type: 'Int', inputType: "Int"
                hideInListPage: true
    }
    F_MongoIndex: {
        system: true, noPatchSystemFields: true
        name: 'F_MongoIndex', label: 'MongoDB索引'
        db: Meta.DB.none
        digestFields: 'name,fields'
        fields:
            name:
                name: 'name', label: '索引名', type: 'String', inputType: "Text"
            fields:
                name: 'fields', label: '字段', type: 'String', inputType: "TextArea"
                comment: "格式：name:-1,_createdOn:-1"
            unique:
                name: 'unique', label: 'unique', type: 'Boolean', inputType: "Check"
            sparse:
                name: 'sparse', label: 'sparse', type: 'Boolean', inputType: "Check"
            errorMessage:
                name: 'errorMessage', label: '错误消息', type: 'String', inputType: "Text"
    }
    F_MySQLIndex: {
        system: true, noPatchSystemFields: true
        name: 'F_MySQLIndex', label: 'MySQL索引'
        db: Meta.DB.none
        digestFields: 'name,fields'
        fields:
            name:
                name: 'name', label: '索引名', type: 'String', inputType: "Text"
            fields:
                name: 'fields', label: '字段', type: 'String', inputType: "TextArea"
                comment: "格式：name:-1,_createdOn:-1"
            unique:
                name: 'unique', label: 'unique', type: 'Boolean', inputType: "Check"
            indexType:
                name: 'indexType', label: 'indexType', type: 'String', inputType: "CheckList"
                options: [{name: "BTREE", label: "BTREE"}, {name: "HASH", label: "HASH"},
                    {name: "RTREE", label: "RTREE"}]
            errorMessage:
                name: 'errorMessage', label: '错误消息', type: 'String', inputType: "Text"
    }
    F_SystemConfig: {
        system: true, name: 'F_SystemConfig', label: '系统配置'
        db: Meta.DB.mongo, tableName: 'F_SystemConfig'
        fields:
            key:
                name: 'key', label: 'KEY', type: 'String', inputType: "Text", persistType: "String"
            mail:
                name: 'systemMail', label: '发信邮箱', type: 'String', inputType: "Text", persistType: "String"
            mailPassword:
                name: 'mailPassword', label: '发信密码', type: 'String', inputType: "Text", persistType: "String"
            mailHost:
                name: 'mailHost', label: '发信HOST', type: 'String', inputType: "Text", persistType: "String"
            mailPort:
                name: 'mailPort', label: '发信PORT', type: 'String', inputType: "Text", persistType: "String"
    }
    F_Menu: {
        system: true,
        name: "F_Menu", label: '菜单', db: Meta.DB.mongo, tableName: 'F_Menu',
        fields:
            menuGroups:
                name: "menuGroups", label: "菜单组", type: 'Component', refEntity: "F_MenuGroup",
                inputType: "InlineComponent", multiple: true
    }
    F_MenuGroup: {
        system: true,
        name: "F_MenuGroup", label: '菜单组', db: Meta.DB.none
        fields:
            label:
                name: 'label', label: '显示名', type: 'String', inputType: "Text"
            menuItems:
                name: "menuItems", label: "菜单项", type: 'Component', refEntity: "F_MenuItem",
                inputType: "PopupComponent", multiple: true
    }
    F_MenuItem: {
        system: true,
        name: "F_MenuItem", label: '菜单项', db: Meta.DB.none
        digestFields: "label,toEntity,callFunc"
        fields:
            label:
                name: 'label', label: '显示名', type: 'String', inputType: "Text"
            toEntity:
                name: 'toEntity', label: '到实体', type: 'String', inputType: "Text"
            callFunc:
                name: 'callFunc', label: '调用函数名', type: 'String', inputType: "Text"
    }
    F_User: {
        system: true, idType: 'String'
        name: 'F_User', label: '用户',
        db: Meta.DB.mongo, tableName: 'F_User'
        digestFields: 'username|nickname|phone|email|_id'
        mongoIndexes: [
            {name: "username", fields: "username:1", unique: true, sparse: true, errorMessage: "用户名重复"}
            {name: "phone", fields: "phone:1", unique: true, sparse: true, errorMessage: "手机已被注册"}
            {name: "email", fields: "email:1", unique: true, sparse: true, errorMessage: "邮箱已被注册"}
            {name: "nickname", fields: "nickname:1", unique: true, sparse: true, errorMessage: "昵称已被注册"}
        ]
        fields:
            username:
                name: 'username', label: '用户名', asFastFilter: true
                type: 'String', inputType: "Text", persistType: "String"
            nickname:
                name: 'nickname', label: '昵称', asFastFilter: true
                type: 'String', inputType: "Text", persistType: "String"
            password:
                name: 'password', label: '密码'
                type: 'Password', inputType: "Password", persistType: "String"
            phone:
                name: 'phone', label: '手机', asFastFilter: true
                type: 'String', inputType: "Text", persistType: "String"
            email:
                name: 'email', label: '邮箱', asFastFilter: true
                type: 'String', inputType: "Text", persistType: "String"
            admin:
                name: 'admin', label: '超管'
                type: 'Boolean', inputType: "Check", persistType: "Boolean"
            disabled:
                name: 'disabled', label: '禁用'
                type: 'Boolean', inputType: "Check", persistType: "Boolean"
            roles:
                name: 'roles', label: '角色'
                type: 'Reference', multiple: true, inputType: "Reference", refEntity: "F_UserRole"
                persistType: "String"
            acl:
                name: 'acl', label: 'ACL'
                type: 'Object', multiple: false, inputFunc: "F.inputACL", persistType: "Document", hideInListPage: true
    }
    F_UserRole: {
        system: true, idType: 'String'
        name: 'F_UserRole', label: '用户角色',
        db: Meta.DB.mongo, tableName: 'F_UserRole'
        digestFields: 'name'
        fields:
            name:
                name: 'name', label: '角色名', asFastFilter: true
                type: 'String', inputType: "Text", persistType: "String"
            acl:
                name: 'acl', label: 'ACL'
                type: 'Object', multiple: false, inputFunc: "F.inputACL", persistType: "Document", hideInListPage: true
    }
    F_UserSession:
        system: true
        name: 'F_UserSession', label: '用户Session',
        db: Meta.DB.mongo, tableName: 'F_UserSession'
        digestFields: ''
        fields:
            userId:
                name: 'userId', label: '用户ID'
                type: 'String', inputType: "Text", persistType: "String"
            userToken:
                name: 'userToken', label: '用户TOKEN'
                type: 'String', inputType: "Text", persistType: "String"
            expireAt:
                name: 'expireAt', label: '过期时间'
                type: 'Int', inputType: "Int", persistType: "Int"
    F_ListFilters:
        system: true
        name: 'F_ListFilters', label: '列表查询条件',
        db: Meta.DB.mongo, tableName: 'F_ListFilters'
        digestFields: 'name,entityName'
        fields:
            name:
                name: 'name', label: '名字'
                type: 'String', inputType: "Text", persistType: "String"
            entityName:
                name: 'entityName', label: '实体名'
                type: 'String', inputType: "Text", persistType: "String"
            criteria:
                name: 'criteria', label: '条件'
                type: 'String', inputType: "TextArea", persistType: "String"
            sortBy:
                name: 'sortBy', label: '排序字段'
                type: 'String', inputType: "Text", persistType: "String"
            sortOrder:
                name: 'sortOrder', label: '顺序'
                type: 'String', inputType: "Text", persistType: "String"
    F_Payment:
        system: true
        name: 'F_Payment', label: '支付记录',
        db: Meta.DB.mysql, tableName: 'F_Payment'
        digestFields: '_id,provider,state,business,businessId'
        fields:
            state:
                name: 'state', label: '状态'
                type: 'Int', inputType: "Int", noCreate: true, noEdit: true, persistType: "tinyint", sqlColM: 1
                options: [{name: 0, label: '未支付'}, {name: 1, label: '成功'}, {name: 2, label: '失败'}]
            stateDecidedOn:
                name: 'stateDecidedOn', label: '状态确定时间'
                type: 'Date', inputType: "Date", noCreate: true, noEdit: true, persistType: "timestamp"
            provider:
                name: 'provider', label: '支付渠道'
                type: 'Int', noCreate: true, noEdit: true, persistType: "varchar", sqlColM: 10
                inputType: "Select",
                options: [{name: 'aliweb', label: '支付宝网页'}, {name: 'weixinweb', label: '微信网页'}]
                required: true
            amount:
                name: 'amount', label: '金额'
                type: 'Int', inputType: "Int", noCreate: true, noEdit: true, persistType: "bigint", sqlColM: 15
                required: true
            business:
                name: 'business', label: '业务类型'
                type: 'String', inputType: "Text", noCreate: true, noEdit: true,
                persistType: "varchar", sqlColM: 20
            businessId:
                name: 'businessId', label: '业务单号'
                type: 'String', inputType: "Text", noCreate: true, noEdit: true,
                persistType: "varchar", sqlColM: 40
            providerFlowNo:
                name: 'providerFlowNo', label: '渠道单号'
                type: 'String', inputType: "Text", noCreate: true, noEdit: true,
                persistType: "varchar", sqlColM: 60
            buyer:
                name: 'buyer', label: '付款人'
                type: 'String', inputType: "Text", noCreate: true, noEdit: true,
                persistType: "varchar", sqlColM: 60
    F_TppCallback:
        system: true
        name: 'F_TppCallback', label: '第三方支付回调',
        db: Meta.DB.mongo, tableName: 'F_TppCallback'
        digestFields: ''
        fields:
            payTranId:
                name: 'payTranId', label: '支付', type: 'Reference', refEntity: 'F_TppTran',
                inputType: "Reference", noCreate: true, noEdit: true,
                persistType: "String"
            tpTradeNo:
                name: 'tpTradeNo', label: '渠道单号'
                type: 'String', inputType: "Text", noCreate: true, noEdit: true, persistType: "String"
            tpResultCode:
                name: 'tpResultCode', label: '渠道结果代码'
                type: 'String', inputType: "Text", noCreate: true, noEdit: true, persistType: "String"
            tpResultMessage:
                name: 'tpResultMessage', label: '渠道结果'
                type: 'String', inputType: "Text", noCreate: true, noEdit: true, persistType: "String"
            buyer:
                name: 'buyer', label: '付款人'
                type: 'String', inputType: "Text", noCreate: true, noEdit: true, persistType: "String"
            source:
                name: 'source', label: '回调途径'
                type: 'String', inputType: "Select", noCreate: true, noEdit: true, persistType: "String"
                options: [{name: 'page', label: '界面'}, {name: 'server', label: '服务器'}]
            callbackBody:
                name: 'callbackBody', label: '回调全文'
                type: 'String', inputType: "TextArea", noCreate: true, noEdit: true, persistType: "String"
    F_PageHead:
        system: true
        name: 'F_PageHead', label: '页面头部信息',
        db: Meta.DB.mongo, tableName: 'F_PageHead'
        digestFields: 'key'
        fields:
            key:
                name: 'key', label: 'KEY', asFastFilter: true
                type: 'String', inputType: "Text", persistType: "String"
            title:
                name: 'title', label: 'title', asFastFilter: true
                type: 'String', inputType: "Text", persistType: "String"
            keyword:
                name: 'keyword', label: 'keyword'
                type: 'String', inputType: "Text", persistType: "String"
    F_Promotion:
        system: true
        name: 'F_Promotion', label: '推广活动',
        db: Meta.DB.mongo, tableName: 'F_Promotion'
        digestFields: 'name'
        fields:
            name:
                name: 'name', label: 'KEY', asFastFilter: true
                type: 'String', inputType: "Text", persistType: "String"
            pagePath:
                name: 'pagePath', label: '页面路径'
                type: 'String', inputType: "Text", persistType: "String"
    F_PromotionPageView:
        system: true, noServiceCache: true
        name: 'F_PromotionPageView', label: '推广活动PV记录',
        db: Meta.DB.mongo, tableName: 'F_PromotionPageView'
        digestFields: '',
        mongoIndexes: [
            {name: "query", fields: "promotion:1,occurOn:1", unique: false, sparse: false}
        ]
        fields:
            promotion:
                name: 'promotion', label: '活动'
                type: 'String', inputType: "Text", persistType: "String"
            uid:
                name: 'uid', label: '追踪标记'
                type: 'String', inputType: "Text", persistType: "String"
            userIp:
                name: 'userIp', label: '用户IP'
                type: 'String', inputType: "Text", persistType: "String"
            userAgent:
                name: 'userAgent', label: 'User Agent'
                type: 'String', inputType: "Text", persistType: "String"
            occurOn:
                name: 'occurOn', label: '发生时间'
                type: 'DateTime', inputType: "DateTime", persistType: "Date"
    F_PromotionShareTrack:
        system: true, noServiceCache: true
        name: 'F_PromotionShareTrack', label: '推广活动分享记录',
        db: Meta.DB.mongo, tableName: 'F_PromotionShareTrack'
        digestFields: '',
        mongoIndexes: [
            {name: "query", fields: "promotion:1,occurOn:1", unique: false, sparse: false}
        ]
        fields:
            promotion:
                name: 'promotion', label: '活动'
                type: 'String', inputType: "Text", persistType: "String"
            channel:
                name: 'channel', label: '来源'
                type: 'String', inputType: "Text", persistType: "String"
            uid:
                name: 'uid', label: '追踪标记'
                type: 'String', inputType: "Text", persistType: "String"
            userIp:
                name: 'userIp', label: '用户IP'
                type: 'String', inputType: "Text", persistType: "String"
            userAgent:
                name: 'userAgent', label: 'User Agent'
                type: 'String', inputType: "Text", persistType: "String"
            occurOn:
                name: 'occurOn', label: '发生时间'
                type: 'DateTime', inputType: "DateTime", persistType: "Date"
    F_PromotionNocookieView:
        system: true, noServiceCache: true
        name: 'F_PromotionNocookieView', label: '推广活动无Cookie浏览记录',
        db: Meta.DB.mongo, tableName: 'F_PromotionNocookieView'
        digestFields: '',
        mongoIndexes: [
            {name: "query", fields: "promotion:1,occurOn:1", unique: false, sparse: false}
        ]
        fields:
            promotion:
                name: 'promotion', label: '活动'
                type: 'String', inputType: "Text", persistType: "String"
            channel:
                name: 'channel', label: '来源'
                type: 'String', inputType: "Text", persistType: "String"
            userIp:
                name: 'userIp', label: '用户IP'
                type: 'String', inputType: "Text", persistType: "String"
            userAgent:
                name: 'userAgent', label: 'User Agent'
                type: 'String', inputType: "Text", persistType: "String"
            occurOn:
                name: 'occurOn', label: '发生时间'
                type: 'DateTime', inputType: "DateTime", persistType: "Date"
}

SystemViews = {
    F_UserView: {
        system: true, name: 'F_UserView', backEntity: 'F_User'
        label: '用户视图1', digestFields: 'username|nickname|phone|email|_id'
        editEnhanceFunc: ''
        fields:
            username:
                name: 'username'
            nickname:
                name: 'nickname'
            phone:
                name: 'phone'
            email:
                name: 'email'
            disabled:
                name: 'disabled'
    }
}

for entityName, entityMeta of SystemEntities
    #unless entities[entityName] # TODO 测试阶段覆盖
    patchSystemFields(entityMeta) unless entityMeta.noPatchSystemFields
    delete entityMeta.idType
    entityMeta.system = true

for viewName, viewMeta of SystemViews
    #unless entities[entityName] # TODO 测试阶段覆盖
    patchSystemFields(viewMeta) unless viewMeta.noPatchSystemFields
    viewMeta.system = true

exports.SystemEntities = SystemEntities
exports.SystemViews = SystemViews

