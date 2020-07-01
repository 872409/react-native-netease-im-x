package com.netease.im.session;

import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;

import androidx.annotation.RequiresApi;
import androidx.core.app.NotificationCompat;

import android.os.Build;
import android.text.TextUtils;

import com.alibaba.fastjson.JSON;
import com.alibaba.fastjson.JSONObject;
import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;
import com.netease.im.IMApplication;
import com.netease.im.RNNeteaseImModule;
import com.netease.im.ReactCache;
import com.netease.im.ReactExtendsion;
import com.netease.im.ReactNativeJson;
import com.netease.im.login.LoginService;
import com.netease.im.session.extension.RedPacketOpenAttachement;
import com.netease.im.uikit.cache.NimUserInfoCache;
import com.netease.im.uikit.cache.TeamDataCache;
import com.netease.im.uikit.common.util.log.LogUtil;
import com.netease.nimlib.sdk.InvocationFuture;
import com.netease.nimlib.sdk.NIMClient;
import com.netease.nimlib.sdk.NimIntent;
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
//        CustomPushContentProvider customConfig = null;//NimUIKit.getCustomPushContentProvider();
//        if (customConfig != null) {
//            String content = customConfig.getPushContent(message);
//            Map<String, Object> payload = customConfig.getPushPayload(message);
        message.setPushContent(message.getContent());
        Map<String, Object> payload = new HashMap<>();
        Map<String, Object> body = new HashMap<>();

        body.put("sessionType", String.valueOf(message.getSessionType().getValue()));
        if (message.getSessionType() == SessionTypeEnum.P2P) {
            body.put("sessionId", LoginService.getInstance().getAccount());
        } else if (message.getSessionType() == SessionTypeEnum.Team) {
            body.put("sessionId", message.getSessionId());

        }
        body.put("sessionName", SessionUtil.getSessionName(message.getSessionId(), message.getSessionType(), true));
        payload.put("payload", body);
        message.setPushPayload(payload);
//        }
    }
//
//    private static void appendPushConfig(IMMessage message) {
////        CustomPushContentProvider customConfig = NimUIKit.getCustomPushContentProvider();
////        if (customConfig != null) {
////            String content = customConfig.getPushContent(message);
////            Map<String, Object> payload = customConfig.getPushPayload(message);
////            message.setPushContent(content);
////            message.setPushPayload(payload);
////        }
//    }

//    /**
//     * 设置最近联系人的消息为已读
//     *
//     * @param enable
//     */
//    private void enableMsgNotification(boolean enable) {
//        if (enable) {
//            /**
//             * 设置最近联系人的消息为已读
//             *
//             * @param account,    聊天对象帐号，或者以下两个值：
//             *                    {@link #MSG_CHATTING_ACCOUNT_ALL} 目前没有与任何人对话，但能看到消息提醒（比如在消息列表界面），不需要在状态栏做消息通知
//             *                    {@link #MSG_CHATTING_ACCOUNT_NONE} 目前没有与任何人对话，需要状态栏消息通知
//             */
//            NIMClient.getService(MsgService.class).setChattingAccount(MsgService.MSG_CHATTING_ACCOUNT_NONE, SessionTypeEnum.None);
//        } else {
//            NIMClient.getService(MsgService.class).setChattingAccount(MsgService.MSG_CHATTING_ACCOUNT_ALL, SessionTypeEnum.None);
//        }
//    }

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


    private static void handleRTCNotice(CustomNotification customNotification) {
        if (ReactCache.mainActiveInBackground()) {
            startApp(IMApplication.getContext());
        }
    }

    public static void receiver(NotificationManager manager, CustomNotification customNotification) {

        LogUtil.w("SessionUtil receiver", customNotification.getContent());
//        customNotification.getTime()
        Map<String, Object> map = customNotification.getPushPayload();
//        LogUtil.w("SessionUtil payload", ReactNativeJson.convertMapToJson(ReactExtendsion.makeHashMap2WritableMap(map)).toJSONString());
        if (map != null && map.containsKey("type")) {
            String type = (String) map.get("type");
            LogUtil.w("receiver", type);


//            if (map.containsKey("payload")) {
//                HashMap payload = (HashMap) map.get("payload");
//                if (payload.containsKey("msg")) {
//                    LogUtil.w("receiver msg", (String) payload.get("msg"));
//                }
//                LogUtil.w("receiver payload", ReactNativeJson.convertMapToJson(ReactExtendsion.makeHashMap2WritableMap(payload)).toJSONString());
//            }

//            LogUtil.w("c type", type);
//            if (SessionUtil.CUSTOM_Notification.equals(type)) {
//                NotificationCompat.Builder builder = new NotificationCompat.Builder(IMApplication.getContext());
//                builder.setContentTitle("请求加为好友");
//                builder.setContentText(customNotification.getApnsText());
//                builder.setAutoCancel(true);
//                PendingIntent contentIntent = PendingIntent.getActivity(
//                        IMApplication.getContext(), 0, new Intent(IMApplication.getContext(), IMApplication.getMainActivityClass()), 0);
//                builder.setContentIntent(contentIntent);
//                builder.setSmallIcon(IMApplication.getNotify_msg_drawable_id());
//                manager.notify((int) System.currentTimeMillis(), builder.build());
//            }

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

            if ("Notice_RTC".equals(type)) {
                handleRTCNotice(customNotification);
            }

            if (!ReactCache.emit(ReactCache.observeCustomNotice, ReactExtendsion.makeHashMap2WritableMap(map))) {
                RNNeteaseImModule.lastCustomNotification = customNotification;
                startApp(IMApplication.getContext());
            }
        }
    }

    public static void startApp(Context content) {
        Intent launchIntent = content.getPackageManager().getLaunchIntentForPackage(content.getPackageName());
        launchIntent.setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_NEW_TASK);
        Intent payload = new Intent();
        payload.putExtra(NimIntent.EXTRA_NOTIFY_CONTENT, NimIntent.EXTRA_NOTIFY_CONTENT);
//        launchIntent.putExtras(payload);
        content.startActivity(launchIntent);
    }

    /**
     * @param account
     * @param sessionType
     * @param type
     * @param content
     */
    public static InvocationFuture<Void> sendCustomNotification(String account, SessionTypeEnum sessionType, String type, String content) {
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

        return NIMClient.getService(MsgService.class).sendCustomNotification(notification);
    }

    /**
     * //TODO:X
     *
     * @param options
     */
    public static InvocationFuture<Void> sendCustomNotification(ReadableMap options, ReadableMap payload) {

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


        String content = ReactNativeJson.convertMapToJson(payload).toJSONString();
        notification.setContent(content);
        notification.setSendToOnlineUserOnly(options.getBoolean("sendToOnlineUsersOnly"));
        notification.setApnsText(options.getString("apns"));

        if (notification.getApnsText() == null || notification.getApnsText().length() == 0) {
            config.enablePush = false;
        }

        notification.setConfig(config);

        String apns_sound = options.hasKey("apns_sound") ? options.getString("apns_sound") : "default";
        String apnsType = options.hasKey("apnsType") ? options.getString("apnsType") : "";

        Map<String, Object> pushPayload = new HashMap<>();
        pushPayload.put("type", apnsType == null ? "" : apnsType);
        pushPayload.put("sound", apns_sound == null ? "" : apns_sound);
        pushPayload.put("payload", content);
        notification.setPushPayload(pushPayload);

       return NIMClient.getService(MsgService.class).sendCustomNotification(notification);
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
