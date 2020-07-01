package com.netease.im.uikit.session.helper;

import com.facebook.react.bridge.WritableMap;
import com.facebook.react.bridge.WritableNativeMap;
import com.netease.im.MessageConstant;
import com.netease.im.NIMSession;
import com.netease.im.login.LoginService;
import com.netease.im.uikit.cache.NimUserInfoCache;
import com.netease.im.uikit.cache.TeamDataCache;
import com.netease.nimlib.sdk.NIMClient;
import com.netease.nimlib.sdk.msg.MessageBuilder;
import com.netease.nimlib.sdk.msg.MsgService;
import com.netease.nimlib.sdk.msg.constant.MsgStatusEnum;
import com.netease.nimlib.sdk.msg.constant.SessionTypeEnum;
import com.netease.nimlib.sdk.msg.model.CustomMessageConfig;
import com.netease.nimlib.sdk.msg.model.IMMessage;
import com.netease.nimlib.sdk.team.constant.TeamTypeEnum;
import com.netease.nimlib.sdk.team.model.Team;

import java.util.HashMap;
import java.util.Map;

/**
 * Created by hzxuwen on 2016/8/19.
 */
public class MessageHelper {

    public static MessageHelper getInstance() {
        return InstanceHolder.instance;
    }

    static class InstanceHolder {
        final static MessageHelper instance = new MessageHelper();
    }

    public static Map<String, Object> makeRevokeMessageOption(IMMessage message, NIMSession session, boolean isSelf, String fromAccount) {
        Map<String, Object> map = new HashMap<>();
        Map<String, Object> format = new HashMap<>();


        map.put("msgId", message.getUuid());
        map.put("msgType", "notification");
        map.put("tipType", "revoke");
        map.put("sessionType", session.sessionType.getValue());
        map.put("sessionId", session.sessionId);
        String tipMsg = "notification_";

        if (session.sessionType == SessionTypeEnum.P2P) {
            map.put("notificationType", "p2p");
            if (!isSelf) {
                String source = NimUserInfoCache.getInstance().getUserDisplayName(fromAccount);
                format.put("source", source != null ? source : "");
                map.put("operationType", "p2p_revoked");
                tipMsg += "p2p_revoked";
            } else {
                map.put("operationType", "you_revoked");
                tipMsg += "you_revoked";
            }
        } else if (session.sessionType == SessionTypeEnum.Team) {
            map.put("notificationType", "team");

            if (!isSelf) {
                String source = TeamDataCache.getInstance().getTeamMemberDisplayName(session.sessionId, fromAccount);
                format.put("source", source != null ? source : "");
                map.put("operationType", "member_revoked");
                tipMsg += "member_revoked";
            } else {
                map.put("operationType", "you_revoked");
                tipMsg += "you_revoked";
            }
        }

        map.put("format", format);
        map.put("tipMsg", tipMsg);
        return map;
    }

    // 消息撤回
    @SuppressWarnings({ "unchecked" })
    public void onRevokeMessage(IMMessage item, boolean isSelf, String fromAccount) {
        if (item == null) {
            return;
        }
        if (item.getSessionType() == SessionTypeEnum.Team) {
            Team t = TeamDataCache.getInstance().getTeamById(item.getSessionId());
            if (t == null || !t.isMyTeam()) {
                return;
            }
        }

        NIMSession session = NIMSession.makeFromIMMessage(item);
        IMMessage message = MessageBuilder.createTipMessage(item.getSessionId(), item.getSessionType());
        Map option = MessageHelper.makeRevokeMessageOption(item, session, isSelf, fromAccount);
//        String nick = "";
//        if (item.getSessionType() == SessionTypeEnum.Team) {
//            nick = TeamDataCache.getInstance().getTeamMemberDisplayNameYou(item.getSessionId(), item.getFromAccount());
//        } else if (item.getSessionType() == SessionTypeEnum.P2P) {
//            nick = item.getFromAccount().equals(LoginService.getInstance().getAccount()) ? "你" : "对方";
//        }
        message.setContent(option.get("tipMsg").toString());
//        message.setPushContent(nick + "撤回了一条消息");
        message.setStatus(MsgStatusEnum.success);
        CustomMessageConfig config = new CustomMessageConfig();
        config.enableUnreadCount = false;
        config.enablePush = false;
        message.setConfig(config);
        message.setLocalExtension(option);
        NIMClient.getService(MsgService.class).saveMessageToLocalEx(message, true, item.getTime());
    }

    public void onCreateTeamMessage(Team team) {
        if (team == null || team.getType() == TeamTypeEnum.Normal) {
            return;
        }
        Map<String, Object> content = new HashMap<>(1);
        content.put("content", "成功创建群");
        IMMessage msg = MessageBuilder.createTipMessage(team.getId(), SessionTypeEnum.Team);
        msg.setRemoteExtension(content);
        CustomMessageConfig config = new CustomMessageConfig();
        config.enableUnreadCount = false;
        config.enablePush = false;
        msg.setConfig(config);
        msg.setStatus(MsgStatusEnum.success);
        NIMClient.getService(MsgService.class).saveMessageToLocal(msg, true);
    }
}
