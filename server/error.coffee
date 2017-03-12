errors = {}

define = (code, message)-> errors[code] = message

define 'DupKey', '数据重复'
define 'ConcurrentUpdate', '修改冲突'

define 'NoSuchEntity', '操作对象不存在'

define 'CreateNotAllow', '不允许创建'
define 'EditNotAllow', '不允许编辑'
define 'DeleteNotAllow', '不允许删除'

define 'EmptyOperation', '空操作'

define "BadQueryCriteria", "查询条件Criteria错误"

define "SubAppNotExisted", "无此应用"

define "UserNotExisted", "无此用户"
define "UserDisabled", "被禁用用户"
define "PasswordNotMatch", "密码错误"

define 'BadPasswordFormat', '密码格式不符合要求'

define 'SecurityCodeNotMatch', '验证码错误'
define 'SecurityCodeExpired', '验证码失效或过期'

define 'CaptchaWrong', '图形验证码错误'

define 'PayTranNotFound', '查无此交易'

define 'PayTranStateChangeIllegal', '支付状态修改非法'

define 'BadAmount', '金额错误'

class MyError extends Error
    constructor: (@code, message)->
        @message = message || errors[@code]
        super @message
        this.stack = (new Error()).stack
    describe: ->
        {code: @code, message: @message}

class UserError extends MyError
    constructor: (@code, message)->
        super @code, message

class UniqueConflictError extends UserError
    constructor: (@code, message, @key)->
        super @code, message

class SystemError extends MyError
    constructor: (@code, message)->
        super @code, message

class Error401 extends MyError
    constructor: (@code, message)->
        super @code, message

class Error403 extends MyError
    constructor: ()->
        super "", ""

exports.UserError = UserError
exports.UniqueConflictError = UniqueConflictError
exports.SystemError = SystemError
exports.Error401 = Error401
exports.Error403 = Error403