package com.netease.im.session;

import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Intent;

import androidx.core.app.NotificationCompat;

import android.text.TextUtils;

import com.alibaba.fastjson.JSON;
import com.alibaba.fastjson.JSONObject;
import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;
import com.netease.im.IMApplication;
import com.netease.im.ReactCache;
import com.netease.im.ReactExtendsion;
import com.netease.im.ReactNativeJson;
import com.netease.im.login.LoginService;
import com.netease.im.session.extension.RedPacketOpenAttachement;
import com.netease.im.uikit.cache.NimUserInfoCache;
import com.netease.im.uikit.cache.TeamDataCache;
import com.netease.im.uikit.common.util.log.LogUtil;
import com.netease.nimlib.sdk.NIMClient;
import com.netease.nimlib.sdk.friend.constant.VerifyType;
import com.netease.nimlib.sdk.msg.MessageBuilder;
import com.netease.nimlib.sdk.msg.MsgService;
import com.netease.nimlib.sdk.msg.constant.MsgStatusEnum;
import com.netease.nimlib.sdk.msg.constant.SessionTypeEnum;
import com.netease.nimlib.sdk.msg.model.CustomMessageConfig;
import com.netease.nimlib.sdk.msg.model.CustomNotification;
import com.netease.nimlib.sdk.msg.model.CustomNotificationConfig;
import com.netease.nimlib.sdk.msg.model.IMMessage;
import com.netease.nimlib.sdk.uinfo.model.NimUserInfo;

import java.util.HashMap;
import java.util.Map;

/**
 * Created by dowin on 2017/5/2.
 */

public class SessionUtil {

    public final static String CUSTOM_Notification = "1";
    public final static String CUSTOM_Notification_redpacket_open = "2";
    public final static String CUSTOM_Notification_RTCCallNotice = "103";
    public final static String CUSTOM_Notification_RTCCallMessage = "103";

    public static SessionTypeEnum getSessionType(String sessionType) {
        return getSessionType(Integer.parseInt(sessionType));
    }

    public static SessionTypeEnum getSessionType(Integer sessionType) {
        SessionTypeEnum sessionTypeE = SessionTypeEnum.None;
        try {
            sessionTypeE = SessionTypeEnum.typeOfValue(sessionType);
        } catch (NumberFormatException e) {
            e.printStackTrace();
        }
        return sessionTypeE;
    }

    public static String getSessionName(String sessionId, SessionTypeEnum sessionTypeEnum, boolean selfName) {
        String name = sessionId;
        if (sessionTypeEnum == SessionTypeEnum.P2P) {
            NimUserInfoCache nimUserInfoCache = NimUserInfoCache.getInstance();
            String pId = selfName ? LoginService.getInstance().getAccount() : sessionId;
            name = nimUserInfoCache.getUserName(pId);
        } else if (sessionTypeEnum == SessionTypeEnum.Team) {
            name = TeamDataCache.getInstance().getTeamName(sessionId);
        }
        return name;
    }

    private static void appendPushConfig(IMMessage message) {
//        CustomPushContentProvider customConfig = NimUIKit.getCustomPushContentProvider();
//        if (customConfig != null) {
//            String content = customConfig.getPushContent(message);
//            Map<String, Object> payload = customConfig.getPushPayload(message);
//            message.setPushContent(content);
//            message.setPushPayload(payload);
//        }
    }

    /**
     * 设置最近联系人的消息为已读
     *
     * @param enable
     */
    private void enableMsgNotification(boolean enable) {
        if (enable) {
            /**
             * 设置最近联系人的消息为已读
             *
             * @param account,    聊天对象帐号，或者以下两个值：
             *                    {@link #MSG_CHATTING_ACCOUNT_ALL} 目前没有与任何人对话，但能看到消息提醒（比如在消息列表界面），不需要在状态栏做消息通知
             *                    {@link #MSG_CHATTING_ACCOUNT_NONE} 目前没有与任何人对话，需要状态栏消息通知
             */
            NIMClient.getService(MsgService.class).setChattingAccount(MsgService.MSG_CHATTING_ACCOUNT_NONE, SessionTypeEnum.None);
        } else {
            NIMClient.getService(MsgService.class).setChattingAccount(MsgService.MSG_CHATTING_ACCOUNT_ALL, SessionTypeEnum.None);
        }
    }

    public static void sendMessage(IMMessage message) {

        appendPushConfig(message);
        NIMClient.getService(MsgService.class).sendMessage(message, false);
    }


    /**
     * 添加好友通知
     *
     * @param account
     * @param content
     */
    public static void sendAddFriendNotification(String fromId, String fromName, String account, String content, VerifyType verifyType) {
        WritableMap options = Arguments.createMap();
        options.putString("apns", content);
        options.putString("sessionId", account);
        options.putInt("sessionType", SessionTypeEnum.P2P.getValue());
        options.putBoolean("apnsEnabled", true);
        options.putBoolean("shouldBeCounted", true);
        options.putBoolean("apnsWithPrefix", true);
        options.putBoolean("sendToOnlineUsersOnly", false);

        WritableMap payload = Arguments.createMap();
        payload.putInt("operation", verifyType.getValue());
        payload.putString("contactId", fromId);
        payload.putString("name", fromName);
        payload.putString("content", content);
        sendCustomNotification(options, payload);
//        sendCustomNotification(account, SessionTypeEnum.P2P, CUSTOM_Notification, content);
    }

    public static void receiver(NotificationManager manager, CustomNotification customNotification) {
//        LogUtil.w("SessionUtil content", customNotification.getContent());
        Map<String, Object> map = customNotification.getPushPayload();
        LogUtil.w("SessionUtil payload", ReactNativeJson.convertMapToJson(ReactExtendsion.makeHashMap2WritableMap(map)).toJSONString());
        if (map != null && map.containsKey("type")) {
            String type = (String) map.get("type");
            if (SessionUtil.CUSTOM_Notification.equals(type)) {
                NotificationCompat.Builder builder = new NotificationCompat.Builder(IMApplication.getContext());
                builder.setContentTitle("请求加为好友");
                builder.setContentText(customNotification.getApnsText());
                builder.setAutoCancel(true);
                PendingIntent contentIntent = PendingIntent.getActivity(
                        IMApplication.getContext(), 0, new Intent(IMApplication.getContext(), IMApplication.getMainActivityClass()), 0);
                builder.setContentIntent(contentIntent);
                builder.setSmallIcon(IMApplication.getNotify_msg_drawable_id());
                manager.notify((int) System.currentTimeMillis(), builder.build());
            }

            map.put("timestamp", customNotification.getTime());
            map.put("notificationId", "");

            Map<String, Object> sender = new HashMap<>();
            sender.put("contactId", customNotification.getFromAccount());
            sender.put("sessionId", customNotification.getSessionId());
            sender.put("sessionType", customNotification.getSessionType().getValue());

            if (customNotification.getSessionType() == SessionTypeEnum.P2P) {
                String contactId = customNotification.getFromAccount();
                NimUserInfo userInfo = NimUserInfoCache.getInstance().getUserInfo(contactId);

                if (userInfo != null) {
                    sender.put("name", userInfo.getName());
                    sender.put("avatar", userInfo.getAvatar());
                } else {
                    sender.put("name", "");
                    sender.put("avatar", "");
                }
//                sender.put("contactId", contactId);
            }

            map.put("sender", sender);

            ReactCache.emit(ReactCache.observeCustomNotice, ReactExtendsion.makeHashMap2WritableMap(map));

        }
//        else {
//            String content = customNotification.getContent();
//            if (!TextUtils.isEmpty(content)) {
//                JSONObject object = JSON.parseObject(content);
//                if (object == null) {
//                    return;
//                }
//
//                JSONObject data = object.getJSONObject("data");
//
//                JSONObject dict = data.getJSONObject("dict");
////                String sendId = customNotification.getSessionId();
////                String openId = dict.getString("openId");
////                String hasRedPacket = dict.getString("hasRedPacket");
////                String serialNo = dict.getString("serialNo");
//
////                String timestamp = data.getString("timestamp");
////                long t = customNotification.getTime() / 1000;
////                try {
////                    t = Long.parseLong(timestamp);
////                } catch (NumberFormatException e) {
////                    t = System.currentTimeMillis() / 1000;
////                    e.printStackTrace();
////                }
////                LogUtil.w("timestamp","timestamp:"+timestamp);
////                LogUtil.w("timestamp","t:"+t);
////                LogUtil.w("timestamp",""+data);
////                String sessionId = data.getString("sessionId");
////                String sessionType = data.getString("sessionType");
////                final String id = sessionId;//getSessionType(sessionType) == SessionTypeEnum.P2P ? openId :
////                sendRedPacketOpenLocal(id, getSessionType(sessionType), sendId, openId, hasRedPacket, serialNo, t);
//            }
//        }

    }

    /**
     * @param account
     * @param sessionType
     * @param type
     * @param content
     */
    public static void sendCustomNotification(String account, SessionTypeEnum sessionType, String type, String content) {
        CustomNotification notification = new CustomNotification();
        notification.setSessionId(account);
        notification.setSessionType(sessionType);

        notification.setContent(content);
        notification.setSendToOnlineUserOnly(false);
        notification.setApnsText(content);

        Map<String, Object> pushPayload = new HashMap<>();
        pushPayload.put("type", type);
        pushPayload.put("content", content);
        notification.setPushPayload(pushPayload);

        NIMClient.getService(MsgService.class).sendCustomNotification(notification);
    }

    /**
     * //TODO:X
     *
     * @param options
     */
    public static void sendCustomNotification(ReadableMap options, ReadableMap payload) {

        String sessionId = options.getString("sessionId");
        int sessionTypeInt = options.getInt("sessionType");
        SessionTypeEnum sessionType = getSessionType(sessionTypeInt);

        CustomNotification notification = new CustomNotification();
        notification.setSessionId(sessionId);
        notification.setSessionType(sessionType);

        CustomNotificationConfig config = new CustomNotificationConfig();
        config.enablePush = options.getBoolean("apnsEnabled");
        config.enableUnreadCount = options.getBoolean("shouldBeCounted");
        config.enablePushNick = options.getBoolean("apnsWithPrefix");
        notification.setConfig(config);

        String content = ReactNativeJson.convertMapToJson(payload).toJSONString();
        notification.setContent(content);
        notification.setSendToOnlineUserOnly(options.getBoolean("sendToOnlineUsersOnly"));
        notification.setApnsText(options.getString("apns"));

        String apns_sound = options.hasKey("apns_sound") ? options.getString("apns_sound") : "default";
        String apnsType = options.hasKey("apnsType") ? options.getString("apnsType") : "";

        Map<String, Object> pushPayload = new HashMap<>();
        pushPayload.put("type", apnsType == null ? "" : apnsType);
        pushPayload.put("sound", apns_sound == null ? "" : apns_sound);
        pushPayload.put("payload", content);
        notification.setPushPayload(pushPayload);

        NIMClient.getService(MsgService.class).sendCustomNotification(notification);
    }


    public static void sendRedPacketOpenLocal(String sessionId, SessionTypeEnum sessionType,
                                              String sendId, String openId, String hasRedPacket, String serialNo, long timestamp) {

        CustomMessageConfig config = new CustomMessageConfig();
        config.enableUnreadCount = false;
        config.enablePush = false;
        RedPacketOpenAttachement attachment = new RedPacketOpenAttachement();
        attachment.setParams(sendId, openId, hasRedPacket, serialNo);
        IMMessage message = MessageBuilder.createCustomMessage(sessionId, sessionType, attachment.getTipMsg(true), attachment, config);
        message.setStatus(MsgStatusEnum.success);

        message.setConfig(config);
        NIMClient.getService(MsgService.class).saveMessageToLocalEx(message, true, timestamp * 1000);
    }

    public static void sendRedPacketOpenNotification(String sessionId, SessionTypeEnum sessionType,
                                                     String sendId, String openId, String hasRedPacket, String serialNo, long timestamp) {

        if (TextUtils.equals(sendId, openId)) {
            return;
        }
        Map<String, Object> data = new HashMap<>();
        Map<String, String> dict = new HashMap<>();
        dict.put("sendId", sendId);
        dict.put("openId", openId);
        dict.put("hasRedPacket", hasRedPacket);
        dict.put("serialNo", serialNo);

        data.put("dict", dict);
        data.put("timestamp", Long.toString(timestamp));
        data.put("sessionId", sessionId);
        data.put("sessionType", Integer.toString(sessionType.getValue()));

        CustomNotification notification = new CustomNotification();
        notification.setSessionId(sendId);
        notification.setSessionType(SessionTypeEnum.P2P);
        CustomNotificationConfig config = new CustomNotificationConfig();
        config.enablePush = false;
        config.enableUnreadCount = false;
        notification.setConfig(config);

        notification.setSendToOnlineUserOnly(false);

        Map<String, Object> pushPayload = new HashMap<>();
        pushPayload.put("type", CUSTOM_Notification_redpacket_open);
        pushPayload.put("data", data);
        notification.setPushPayload(pushPayload);

        NIMClient.getService(MsgService.class).sendCustomNotification(notification);
    }
}
