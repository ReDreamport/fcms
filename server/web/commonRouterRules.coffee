router = require './router'

exports.actions =
    ReadMeta: '读取元数据'
    WriteMeta: '修改元数据'
    ChangePassword: '修改密码接口'
    ChangePhone: '修改绑定手机接口'
    ChangeEmail: '修改绑定邮箱接口'
    PreFilters: '管理预定义查询'
    Upload: '文件上传'
    RichTextUpload: '富文本编辑器文件上传'
    ES: '配置搜索引擎'
    Promotion: '推广活动'

exports.addCommonRouteRules = (rrr)->
    # ======================================
    # 元数据管理
    # ======================================
    MetaHandler = require('../handler/MetaHandler')

    rrr.get '/meta', {action: 'ReadMeta'}, MetaHandler.gGetAllMeta
    rrr.get '/meta/entity/_empty', {action: 'WriteMeta'}, MetaHandler.gGetEmptyEntityMeta
    rrr.put '/meta/:type/:name', {action: 'WriteMeta'}, MetaHandler.gSaveMeta
    rrr.del '/meta/:type/:name', {action: 'WriteMeta'}, MetaHandler.gRemoveMeta

    # ======================================
    # 用户
    # ======================================

    UserHandler = require '../handler/UserHandler'

    rrr.get '/ping', {auth: true}, UserHandler.gPing
    rrr.post '/api/sign-in', {}, UserHandler.gSignIn
    rrr.post '/api/sign-out', {auth: true}, UserHandler.gSignOut
    rrr.post '/api/change-password', {action: 'ChangePassword'}, UserHandler.gChangePassword
    rrr.post '/api/reset-password', {}, UserHandler.gResetPassword
    rrr.post '/api/change-phone', {action: 'ChangePhone'}, UserHandler.gChangePhone
    rrr.post '/api/change-email', {action: 'ChangeEmail'}, UserHandler.gChangeEmail

    # ======================================
    # 安全
    # ======================================
    SecurityCodeHandler = require '../handler/SecurityCodeHandler'

    # 发送注册验证码到手机和邮箱
    rrr.post '/security-code/phone/:phone', {}, SecurityCodeHandler.gSendSignUpCodeToPhone
    rrr.post '/security-code/email/:email', {}, SecurityCodeHandler.gSendSignUpCodeToEmail

    CaptchaHandler = require '../handler/CaptchaHandler'
    # 请求一个图形验证码
    rrr.get '/captcha', {}, CaptchaHandler.generate

    # ======================================
    # 实体 CRUD
    # ======================================

    EntityHandler = require('../handler/EntityHandler')

    rrr.get '/entity/:entityName', {auth: 'listEntity'}, EntityHandler.gList
    rrr.get '/entity/:entityName/:id', {auth: 'getEntity'}, EntityHandler.gFindOneById
    rrr.post '/entity/:entityName', {auth: 'createEntity'}, EntityHandler.gCreateEntity
    rrr.put '/entity/:entityName/:id', {auth: 'updateOneEntity'}, EntityHandler.gUpdateEntityById
    rrr.put '/entity/:entityName', {auth: 'updateManyEntity'}, EntityHandler.gUpdateEntityInBatch
    rrr.del '/entity/:entityName', {auth: 'removeEntity'}, EntityHandler.gDeleteEntityInBatch
    rrr.post '/entity/:entityName/recover', {auth: 'recoverEntity'}, EntityHandler.gRecoverInBatch

    rrr.put '/entity/filters', {action: 'PreFilters'}, EntityHandler.gSaveFilters
    rrr.del '/entity/filters', {action: 'PreFilters'}, EntityHandler.gRemoveFilters

    # ======================================
    # 文件
    # ======================================

    UploadHandler = require('../handler/UploadHandler')
    rrr.post '/file', {action: 'Upload'}, UploadHandler.gUpload # h5
    rrr.post '/file2', {action: 'Upload'}, UploadHandler.gUpload2 # transport
    rrr.post '/rich-text-file', {action: 'RichTextUpload'}, UploadHandler.gUploadForRichText

# ======================================
# 搜索引擎
# ======================================

#ElasticSearchController = require '../handler/ElasticSearchController'
#rrr.post '/config-es', {action: 'ES'}, ElasticSearchController.gConfig

# ======================================
# 支付
# ======================================

#TppiHandler = require '../handler/TppiHandler'

#rrr.post '/pay/api/callback/weixin', {}, TppiHandler.gProcessWeixinCallback
#rrr.post '/pay/api/callback/alipay', {}, TppiHandler.gProcessAlipayCallback
# 支付宝前端回调
# rrr.get '/pay/callback/alipay', {}, TppiHandler.toAlipayFrontCallback

# ======================================
# 推广活动
# ======================================

#PromotionHandler = require '../handler/PromotionHandler'

#rrr.get '/pt/:name', {isPage: true}, PromotionHandler.toPromotion
#rrr.del '/pt/_page-cache', {action: 'Promotion'}, PromotionHandler.gInvalidateStaticPageCache
#rrr.post '/pt/_persist-pv-now', {action: 'Promotion'}, PromotionHandler.gPersistPageViewNow
#rrr.get '/pt/_report/:promotion', {action: 'Promotion'}, PromotionHandler.gReport
#rrr.get '/pt/_channels/:promotion', {action: 'Promotion'}, PromotionHandler.gGetPromotionChannels
#rrr.put '/pt/_channels/:promotion', {action: 'Promotion'}, PromotionHandler.gPutPromotionChannels
