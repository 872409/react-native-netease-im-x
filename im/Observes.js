/**
 *监听列表
 *observeRecentContact 最近会话
 *observeOnlineStatus 在线状态
 *observeFriend 联系人/好友
 *observeTeam 群组
 *observeBlackList 黑名单
 *observeReceiveMessage 接收消息
 *observeReceiveSystemMsg 系统通知
 *observeUnreadCountChange 未读消息数
 *observeMsgStatus 发送消息状态变化
 *observeAudioRecord 录音状态
 *observeDeleteMessage 撤销后删除消息
 *observeAttachmentProgress 未读数变化
 *observeOnKick 被踢出下线
 */

/**
 * 最近会话
 * @type {string}
 */
const observeRecentContact = "observeRecentContact";
/**
 * 在线状态
 * @type {string}
 */
const observeOnlineStatus  = "observeOnlineStatus";

/**
 * 联系人/好友
 * @type {string}
 */
const observeFriend             = "observeFriend";
/**
 * 群组
 * @type {string}
 */
const observeTeam               = "observeTeam";
const observeBlackList          = "observeBlackList";
const observeReceiveMessage     = "observeReceiveMessage";
const observeReceiveSystemMsg   = "observeReceiveSystemMsg";
const observeUnreadCountChange  = "observeUnreadCountChange";
const observeMsgStatus          = "observeMsgStatus";
const observeAudioRecord        = "observeAudioRecord";
const observeDeleteMessage      = "observeDeleteMessage";
const observeAttachmentProgress = "observeAttachmentProgress";
const observeOnKick             = "observeOnKick";


export default {
    observeRecentContact,
    observeOnlineStatus,
    observeFriend,
    observeTeam,
    observeBlackList,
    observeReceiveMessage,
    observeReceiveSystemMsg,
    observeUnreadCountChange,
    observeMsgStatus,
    observeAudioRecord,
    observeDeleteMessage,
    observeAttachmentProgress,
    observeOnKick
};
