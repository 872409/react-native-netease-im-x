package com.netease.im;

import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ApplicationInfo;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.location.LocationProvider;
import android.os.Build;
import android.os.Environment;

import androidx.annotation.DrawableRes;
import androidx.annotation.RequiresApi;
import androidx.core.app.NotificationCompat;

import android.text.TextUtils;
import android.util.Log;

import com.alibaba.fastjson.JSON;
import com.netease.im.common.ImageLoaderKit;
import com.netease.im.common.sys.SystemUtil;
import com.netease.im.contact.DefaultContactProvider;
import com.netease.im.contact.DefaultUserInfoProvider;
import com.netease.im.login.LoginService;
import com.netease.im.session.SessionUtil;
import com.netease.im.session.extension.CustomAttachParser;
import com.netease.im.uikit.LoginSyncDataStatusObserver;
import com.netease.im.uikit.cache.DataCacheManager;
import com.netease.im.uikit.common.util.log.LogUtil;
import com.netease.im.uikit.common.util.media.ImageUtil;
import com.netease.im.uikit.common.util.storage.StorageType;
import com.netease.im.uikit.common.util.storage.StorageUtil;
import com.netease.im.uikit.common.util.sys.ScreenUtil;
import com.netease.im.uikit.contact.core.ContactProvider;
import com.netease.im.uikit.contact.core.query.PinYin;
import com.netease.im.uikit.session.helper.MessageHelper;
import com.netease.nimlib.sdk.NIMClient;
import com.netease.nimlib.sdk.NimIntent;
import com.netease.nimlib.sdk.Observer;
import com.netease.nimlib.sdk.SDKOptions;
import com.netease.nimlib.sdk.StatusBarNotificationConfig;
import com.netease.nimlib.sdk.StatusCode;
import com.netease.nimlib.sdk.auth.AuthServiceObserver;
import com.netease.nimlib.sdk.auth.LoginInfo;
import com.netease.nimlib.sdk.mixpush.MixPushConfig;
import com.netease.nimlib.sdk.mixpush.MixPushService;
import com.netease.nimlib.sdk.msg.MessageBuilder;
import com.netease.nimlib.sdk.msg.MessageNotifierCustomization;
import com.netease.nimlib.sdk.msg.MsgService;
import com.netease.nimlib.sdk.msg.MsgServiceObserve;
import com.netease.nimlib.sdk.msg.constant.SessionTypeEnum;
import com.netease.nimlib.sdk.msg.model.CustomNotification;
import com.netease.nimlib.sdk.msg.model.IMMessage;
import com.netease.nimlib.sdk.msg.model.RevokeMsgNotification;
import com.netease.nimlib.sdk.uinfo.UserInfoProvider;
import com.netease.nimlib.sdk.util.NIMUtil;

import java.util.ArrayList;
import java.util.Map;


/**
 * Created by dowin on 2017/4/28.
 */

public class IMApplication {


    private static String TAG = "IMApplication";
    // context
    private static Context context;

    private static Class mainActivityClass;
    @DrawableRes
    private static int notify_msg_drawable_id;
    // 用户信息提供者
    private static UserInfoProvider userInfoProvider;

    // 通讯录信息提供者
    private static ContactProvider contactProvider;

    // 地理位置信息提供者
    private static LocationProvider locationProvider;

    // 图片加载、缓存与管理组件
    private static ImageLoaderKit imageLoaderKit;
    private static StatusBarNotificationConfig statusBarNotificationConfig;
    private static boolean DEBUG = false;

    public static void init(Context context, Class mainActivityClass, @DrawableRes int notify_msg_drawable_id, ImPushConfig miPushConfig) {
        IMApplication.context = context.getApplicationContext();
        IMApplication.mainActivityClass = mainActivityClass;
        IMApplication.notify_msg_drawable_id = notify_msg_drawable_id;

        // 注册小米推送appID 、appKey 以及在云信管理后台添加的小米推送证书名称，该逻辑放在 NIMClient init 之前
//        if (miPushConfig != null) {
//            MixPushConfig mixPushConfig = new MixPushConfig();
//            mixPushConfig.xmCertificateName = miPushConfig.certificate;
//            mixPushConfig.xmAppId = miPushConfig.appID;
//            mixPushConfig.xmAppKey = miPushConfig.appKey;
//            NIMPushClient.initPush(new MixPushConfig());
//        }

        LoginInfo loginInfo = getLoginInfo();
        NIMClient.init(context, loginInfo, getOptions(context, miPushConfig));


        // crash handler
//        AppCrashHandler.getInstance(context);
        Log.e("MainApplication", NIMClient.getStatus().toString());
        if (NIMUtil.isMainProcess(IMApplication.context)) {

            if (loginInfo != null && loginInfo.getAccount().length() > 0) {
                autoLoginInit(true);
            }

            // init pinyin
            PinYin.init(context);
            PinYin.validate();

            if (miPushConfig != null) {
                NIMClient.getService(MixPushService.class).enable(true);
            }
            // 初始化Kit模块
            initKit();

        }

    }

    static Observer<StatusCode> userStatusObserver = new Observer<StatusCode>() {

        @Override
        public void onEvent(StatusCode statusCode) {
            LogUtil.e(TAG, "userStatusObserver:" + statusCode.toString());
            if (statusCode.equals(StatusCode.LOGINED)) {
                LoginService.getInstance().afterFirstLogin();
            }

        }
    };

    private static void autoLoginInit(boolean register) {
        NIMClient.getService(AuthServiceObserver.class).observeOnlineStatus(userStatusObserver, register);
    }

    public static void setDebugAble(boolean debugAble) {
        DEBUG = debugAble;
        LogUtil.setDebugAble(debugAble);
    }

    //
//    private static Observer<CustomNotification> notificationObserver = new Observer<CustomNotification>() {
//        @Override
//        public void onEvent(CustomNotification customNotification) {
//            NotificationManager notificationManager = (NotificationManager) IMApplication.getContext().getSystemService(Context.NOTIFICATION_SERVICE);
//            SessionUtil.receiver(notificationManager, customNotification);
//        }
//    };
    @RequiresApi(api = Build.VERSION_CODES.LOLLIPOP)
    public static void onReceiveCustomNotification(Context context, Intent intent) {
        String action = context.getPackageName() + NimIntent.ACTION_RECEIVE_CUSTOM_NOTIFICATION;
        Log.e(TAG, "onReceiveCustomNotification");
        if (action.equals(intent.getAction())) {
            CustomNotification notification = (CustomNotification) intent.getSerializableExtra(NimIntent.EXTRA_BROADCAST_MSG);
            NotificationManager notificationManager = (NotificationManager) IMApplication.getContext().getSystemService(Context.NOTIFICATION_SERVICE);
            SessionUtil.receiver(notificationManager, notification);
        }
//        startApp(context);
    }

    public static void startApp(Context content) {
        Intent launchIntent = context.getPackageManager().getLaunchIntentForPackage(content.getPackageName());
        launchIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED);
//            launchIntent.putExtras(bundle);
        context.startActivity(launchIntent);
    }

    public static void mainActivityLaunch(Intent intent) {
        Log.w(TAG, "mainActivityLaunch:" + (intent == null ? "null" : intent.toString()));
        if (intent != null) {
//            if (NIMClient.getService(MixPushService.class).isFCMIntent(intent)) {
//                parseFCMNotifyIntent(NIMClient.getService(MixPushService.class).parseFCMPayload(intent));
//            }
            parseNotifyIntent(intent);
        }
    }

    private static void parseNotifyIntent(Intent intent) {
//        ArrayList<IMMessage> messages = (ArrayList<IMMessage>) intent.getSerializableExtra(NimIntent.EXTRA_NOTIFY_CONTENT);
//        Log.w(TAG, "parseNotifyIntent:" + (messages == null ? "null" : messages.size()));
//        if (ReceiverMsgParser.checkOpen(intent)) {
////            RNNeteaseImModule.launch = intent;
////            IMMessage message = messages.get(0);
////            ReactCache.emit(ReactCache.observeLaunchPushEvent, ReceiverMsgParser.getWritableMap(intent));
////            Log.w(TAG, "parseNotifyIntent getSessionType:" + message.getSessionType() + " getSessionId:" + message.getSessionId() + " " + message.getContent());
//        }
    }

    private static void parseFCMNotifyIntent(String payloadString) {
        Log.w(TAG, "parseFCMNotifyIntent:" + payloadString);
//        Map<String, String> payload = JSON.parseObject(payloadString, Map.class);
//        String sessionId = payload.get("sessionId");
//        String type = payload.get("sessionType");
//        if (sessionId != null && type != null) {
//            int typeValue = Integer.valueOf(type);
//            IMMessage message = MessageBuilder.createEmptyMessage(sessionId, SessionTypeEnum.typeOfValue(typeValue), 0);
//            showMainActivity(new Intent().putExtra(NimIntent.EXTRA_NOTIFY_CONTENT, message));
//        } else {
//            showMainActivity(null);
//        }
    }


//
//    @RequiresApi(api = Build.VERSION_CODES.LOLLIPOP)
//    public static void showRTCNotification(Context context, Intent intent) {
//        final NotificationManager mNotificationManager = (NotificationManager) context.getSystemService(Context.NOTIFICATION_SERVICE);
//
//        NotificationCompat.Builder builder3;
//
//
//        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
//            String channelId = "nim_message_channel_001";
//            builder3 = new NotificationCompat.Builder(context, channelId);
//        } else {
//            builder3 = new NotificationCompat.Builder(context);
//        }
//
//        builder3.setSmallIcon(notify_msg_drawable_id);
//        builder3.setLargeIcon(BitmapFactory.decodeResource(context.getResources(), notify_msg_drawable_id));
//        builder3.setAutoCancel(true);
//        builder3.setDefaults(NotificationCompat.DEFAULT_SOUND);
//        //设置震动方式，延迟零秒，震动一秒，延迟一秒、震动一秒
//        builder3.setVibrate(new long[]{0, 1000, 1000, 1000});
//
//        builder3.setOnlyAlertOnce(false);
//        builder3.setContentTitle("dddd");
//
//
////        Intent intent3 = new Intent(Intent.ACTION_VIEW, Uri.parse("http://www.jianshu.com/p/82e249713f1b"));
//        PendingIntent pendingIntent3 = PendingIntent.getActivity(context, 0, intent, 0);
//        builder3.setContentIntent(pendingIntent3);
//
//
//        Intent XuanIntent = new Intent();
//        XuanIntent.setFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP);
//        XuanIntent.setClass(context, mainActivityClass);
//
//        PendingIntent xuanpengdIntent = PendingIntent.getActivity(context, 0, XuanIntent, PendingIntent.FLAG_UPDATE_CURRENT);
//        builder3.setFullScreenIntent(xuanpengdIntent, true);
//        builder3.setVisibility(NotificationCompat.VISIBILITY_PUBLIC);
//        mNotificationManager.notify(2, builder3.build());
//
//    }


    private static boolean inMainProcess(Context context) {
        String packageName = context.getPackageName();
        String processName = SystemUtil.getProcessName(context);
        return packageName.equals(processName);
    }


    public static Context getContext() {
        return context;
    }

    public static int getNotify_msg_drawable_id() {
        return notify_msg_drawable_id;
    }

    public static Class getMainActivityClass() {
        return mainActivityClass;
    }

    private static LoginInfo getLoginInfo() {
        return LoginService.getInstance().getLoginInfo(context);
    }

    public static String getSdkStorageRooPath() {
        return Environment.getExternalStorageDirectory() + "/" + context.getPackageName() + "/nim";
    }

    private static SDKOptions getOptions(Context context, ImPushConfig miPushConfig) {
        SDKOptions options = new SDKOptions();

        // 如果将新消息通知提醒托管给SDK完成，需要添加以下配置。
        initStatusBarNotificationConfig(options, context);

        // 配置保存图片，文件，log等数据的目录

        options.sdkStorageRootPath = getSdkStorageRooPath();
        options.teamNotificationMessageMarkUnread = true;
        options.sessionReadAck = true;

        // 配置数据库加密秘钥
        options.databaseEncryptKey = "NETEASE";

        // 配置是否需要预下载附件缩略图
        options.preloadAttach = true;

        // 配置附件缩略图的尺寸大小，
        options.thumbnailSize = ImageUtil.getImageMaxEdge();

        // 用户信息提供者
        options.userInfoProvider = new DefaultUserInfoProvider(context);

        // 定制通知栏提醒文案（可选，如果不定制将采用SDK默认文案）
        options.messageNotifierCustomization = messageNotifierCustomization;

        // 在线多端同步未读数
        options.sessionReadAck = true;
        //自动检查 SDK 配置是否完全
        options.checkManifestConfig = DEBUG;
        //reducedIM 支持弱 IM 场景
        //asyncInitSDK 支持异步 SDK 初始化
        //teamNotificationMessageMarkUnread 登录选项添加群通知消息是否计入未读数开关
        //sdkStorageRootPath 配置的外置存储缓存根目录


        // 推送配置
        if (miPushConfig != null) {
            MixPushConfig pushConfig = new MixPushConfig();
            pushConfig.fcmCertificateName = miPushConfig.fcmCertificateName;
            pushConfig.xmAppId = miPushConfig.xmAppId;
            pushConfig.xmAppKey = miPushConfig.xmAppKey;
            pushConfig.xmCertificateName = miPushConfig.xmCertificateName;
            pushConfig.hwCertificateName = miPushConfig.hwCertificateName;
            options.mixPushConfig = pushConfig;
        }

        return options;
    }

    // 这里开发者可以自定义该应用初始的 StatusBarNotificationConfig
    @SuppressWarnings("unchecked")
    private static StatusBarNotificationConfig loadStatusBarNotificationConfig(Context context) {
        StatusBarNotificationConfig config = new StatusBarNotificationConfig();
        // 点击通知需要跳转到的界面
        config.notificationEntrance = mainActivityClass;
        config.notificationSmallIconId = notify_msg_drawable_id;

        // 通知铃声的uri字符串
        config.notificationSound = "android.resource://" + context.getPackageName() + "/raw/msg";

        // 呼吸灯配置
        config.ledARGB = Color.GREEN;
        config.ledOnMs = 1000;
        config.ledOffMs = 1500;

        // save cache，留做切换账号备用
        setStatusBarNotificationConfig(config);
        return config;
    }

    private static void initStatusBarNotificationConfig(SDKOptions options, Context context) {
        // load 应用的状态栏配置
        StatusBarNotificationConfig config = loadStatusBarNotificationConfig(context);

        // load 用户的 StatusBarNotificationConfig 设置项
        StatusBarNotificationConfig userConfig = null;//UserPreferences.getStatusConfig();
        if (userConfig == null) {
            userConfig = config;
        } else {
            // 新增的 UserPreferences 存储项更新，兼容 3.4 及以前版本
            // APP默认 StatusBarNotificationConfig 配置修改后，使其生效
            userConfig.notificationEntrance = config.notificationEntrance;
            userConfig.notificationFolded = config.notificationFolded;
//          userConfig.notificationColor = Color.parseColor("#3a9efb");
        }
        userConfig.showBadge = true;
        // 持久化生效
//        UserPreferences.setStatusConfig(config);
        // SDK statusBarNotificationConfig 生效
        options.statusBarNotificationConfig = userConfig;
    }

    private static MessageNotifierCustomization messageNotifierCustomization = new MessageNotifierCustomization() {
        @Override
        public String makeNotifyContent(String nick, IMMessage message) {
            return null; // 采用SDK默认文案
        }

        @Override
        public String makeTicker(String nick, IMMessage message) {
            return null; // 采用SDK默认文案
        }

        @Override
        public String makeRevokeMsgTip(String revokeAccount, IMMessage item) {
            return MessageUtil.getRevokeTipContent(item, revokeAccount);
        }
    };


    /*********************/
    public static void initKit() {
        NIMClient.getService(MsgService.class).registerCustomAttachmentParser(new CustomAttachParser());
        initUserInfoProvider(userInfoProvider);
        initContactProvider(contactProvider);
//        initDefalutSessionCustomization();
//        initDefalutContactEventListener();

        imageLoaderKit = new ImageLoaderKit(context, null);

        // init data cache
        LoginSyncDataStatusObserver.getInstance().registerLoginSyncDataStatus(true);  // 监听登录同步数据完成通知
        DataCacheManager.observeSDKDataChanged(true);
        if (!TextUtils.isEmpty(getLoginInfo().getAccount())) {
            DataCacheManager.buildDataCache(); // build data cache on auto login
        }

        // init tools
        StorageUtil.init(context, null);
        ScreenUtil.init(context);

        // 注册消息撤回监听器
        registerMsgRevokeObserver();

//        NIMClient.getService(MsgServiceObserve.class).observeCustomNotification(notificationObserver, true);

        // init log
        String path = StorageUtil.getDirectoryByDirType(StorageType.TYPE_LOG);
        LogUtil.init(path, Log.DEBUG);
    }

    public static boolean isApkDebugable(Context context) {
        try {
            ApplicationInfo info = context.getApplicationInfo();
            return (info.flags & ApplicationInfo.FLAG_DEBUGGABLE) != 0;
        } catch (Exception e) {
            e.printStackTrace();
        }
        return false;
    }

    private static void registerMsgRevokeObserver() {
        NIMClient.getService(MsgServiceObserve.class).observeRevokeMessage(new Observer<RevokeMsgNotification>() {
            @Override
            public void onEvent(RevokeMsgNotification message) {
                if (message == null && message.getMessage() == null) {
                    return;
                }

                MessageHelper.getInstance().onRevokeMessage(message.getMessage(), false, message.getRevokeAccount());
            }
        }, true);
    }

    // 初始化用户信息提供者
    private static void initUserInfoProvider(UserInfoProvider userInfoProvider) {

        if (userInfoProvider == null) {
            userInfoProvider = new DefaultUserInfoProvider(context);
        }

        IMApplication.userInfoProvider = userInfoProvider;
    }

    // 初始化联系人信息提供者
    private static void initContactProvider(ContactProvider contactProvider) {

        if (contactProvider == null) {
            contactProvider = new DefaultContactProvider();
        }

        IMApplication.contactProvider = contactProvider;
    }

    public static UserInfoProvider getUserInfoProvider() {
        return userInfoProvider;
    }

    public static ContactProvider getContactProvider() {
        return contactProvider;
    }

    public static ImageLoaderKit getImageLoaderKit() {
        return imageLoaderKit;
    }

    public static void setStatusBarNotificationConfig(StatusBarNotificationConfig statusBarNotificationConfig) {
        IMApplication.statusBarNotificationConfig = statusBarNotificationConfig;
    }

    public static StatusBarNotificationConfig getNotificationConfig() {
        return statusBarNotificationConfig;
    }
}
