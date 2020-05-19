package com.netease.im.login;

import android.app.NotificationManager;
import android.content.Context;
import android.content.SharedPreferences;
import android.os.AsyncTask;
import android.os.Parcel;
import android.preference.PreferenceManager;
import android.util.Log;

import com.netease.im.IMApplication;
import com.netease.im.ReactCache;
import com.netease.im.session.SessionUtil;
import com.netease.im.team.TeamListService;
import com.netease.im.uikit.LoginSyncDataStatusObserver;
import com.netease.im.uikit.cache.DataCacheManager;
import com.netease.nimlib.sdk.AbortableFuture;
import com.netease.nimlib.sdk.NIMClient;
import com.netease.nimlib.sdk.Observer;
import com.netease.nimlib.sdk.RequestCallback;
import com.netease.nimlib.sdk.auth.AuthService;
import com.netease.nimlib.sdk.auth.LoginInfo;
import com.netease.nimlib.sdk.friend.model.AddFriendNotify;
import com.netease.nimlib.sdk.msg.MsgServiceObserve;
import com.netease.nimlib.sdk.msg.SystemMessageObserver;
import com.netease.nimlib.sdk.msg.SystemMessageService;
import com.netease.nimlib.sdk.msg.constant.SystemMessageType;
import com.netease.nimlib.sdk.msg.model.CustomNotification;
import com.netease.nimlib.sdk.msg.model.SystemMessage;

import java.util.prefs.Preferences;

import static android.content.Context.MODE_PRIVATE;

/**
 * Created by dowin on 2017/4/28.
 */

public class LoginService {


    final static String TAG = "LoginService";
    // 自己的用户帐号
    private String account;
    private String token;
    private LoginInfo loginInfo;
    private AbortableFuture<LoginInfo> loginInfoFuture;
    private Context context;

    private LoginService() {

    }

    static class InstanceHolder {
        final static LoginService instance = new LoginService();
    }

    public static LoginService getInstance() {
        return InstanceHolder.instance;
    }

    /**
     * 设置当前登录用户的帐号
     *
     * @param account 帐号
     */
    public void setAccount(String account) {
        this.account = account;
    }

    public String getAccount() {
        return account;
    }

    public LoginInfo getLoginInfo(Context context) {
        Log.w("LoginInfo", "getLoginInfo");
        if (this.context == null) {
            this.context = context;
        }
        if (this.account == null || this.token == null) {
            SharedPreferences preferences = context.getSharedPreferences("im", MODE_PRIVATE);
            if (preferences.contains("LAST_ACCOUNT")) {
                this.loginInfo = new LoginInfo(preferences.getString("LAST_ACCOUNT", ""), preferences.getString("LAST_ACCOUNT_TOKEN", ""));
//                Log.w("LoginInfo", info.getAccount());
//                Log.w("LoginInfo", info.getToken());
                this.account = this.loginInfo.getAccount();
                this.token = this.loginInfo.getToken();
            }
        }

        if (this.loginInfo == null) {
            this.loginInfo = new LoginInfo("", "");
        }

        return this.loginInfo;
    }

    void initLogin(LoginInfo loginInfo) {
        this.account = loginInfo.getAccount();
        this.token = loginInfo.getToken();
        this.loginInfo = loginInfo;


        SharedPreferences preferences = this.context.getSharedPreferences("im", MODE_PRIVATE);
        SharedPreferences.Editor editor = preferences.edit();
        editor.putString("LAST_ACCOUNT", loginInfo.getAccount());
        editor.putString("LAST_ACCOUNT_TOKEN", loginInfo.getToken());
        editor.apply();
        editor.commit();

//        Log.w("LoginInfo", loginInfo.getAccount());
//        Log.w("LoginInfo", loginInfo.getToken());
//        Log.w("LoginInfo", preferences.getString("LAST_ACCOUNT", "empty"));


    }

    public void autoLogin(RequestCallback<LoginInfo> callback) {
        Log.w(TAG, "autoLogin");
        login(getLoginInfo(null), callback);
    }

    public void login(final LoginInfo loginInfoP, final RequestCallback<LoginInfo> callback) {
        loginInfoFuture = NIMClient.getService(AuthService.class).login(loginInfoP);
        loginInfoFuture.setCallback(new RequestCallback<LoginInfo>() {
            @Override
            public void onSuccess(LoginInfo loginInfo) {
                Log.w(TAG, "onSuccess:" + loginInfo.getAccount());
                account = loginInfo.getAccount();
                token = loginInfoP.getToken();
                initLogin(loginInfo);
                if (callback != null) {
                    callback.onSuccess(loginInfo);
                }

                registerObserver(true);
                startLogin();
                loginInfoFuture = null;
            }


            @Override
            public void onFailed(int code) {
                if (callback != null) {
                    callback.onFailed(code);
                }
                registerObserver(true);
                loginInfoFuture = null;
            }

            @Override
            public void onException(Throwable exception) {
                if (callback != null) {
                    callback.onException(exception);
                }
                registerObserver(false);
                loginInfoFuture = null;
            }
        });

    }


    private void startLogin() {
        new AsyncTask<Object, Object, Object>() {

            @Override
            protected Object doInBackground(Object[] params) {
                DataCacheManager.buildDataCacheAsync();
                SysMessageObserver.getInstance().loadMessages(false);
                queryRecentContacts();
                startSystemMsgUnreadCount();
                return null;
            }
        }.executeOnExecutor(AsyncTask.THREAD_POOL_EXECUTOR);

    }

    private void queryRecentContacts() {
        recentContactObserver.queryRecentContacts();
    }

    volatile boolean hasRegister;

    RecentContactObserver recentContactObserver = RecentContactObserver.getInstance();
//    SysMessageObserver sysMessageObserver = new SysMessageObserver();

    synchronized void registerObserver(boolean register) {
        if (hasRegister && register) {
            return;
        }
        hasRegister = register;

        recentContactObserver.registerRecentContactObserver(register);
//        sysMessageObserver.registerSystemObserver(register);
//        NIMClient.getService(SystemMessageObserver.class).observeReceiveSystemMsg(systemMessageObserver, register);
        NIMClient.getService(MsgServiceObserve.class).observeCustomNotification(notificationObserver, register);
        SysMessageObserver.getInstance().register(register);
    }

    private NotificationManager notificationManager;
    private Observer<CustomNotification> notificationObserver = new Observer<CustomNotification>() {
        @Override
        public void onEvent(CustomNotification customNotification) {

            SessionUtil.receiver(getNotificationManager(), customNotification);
        }
    };

    public NotificationManager getNotificationManager() {
        if (notificationManager == null) {
            notificationManager = (NotificationManager) IMApplication.getContext().getSystemService(Context.NOTIFICATION_SERVICE);
        }
        return notificationManager;
    }

    private Observer<SystemMessage> systemMessageObserver = new Observer<SystemMessage>() {
        @Override
        public void onEvent(SystemMessage systemMessage) {
            if (systemMessage.getType() == SystemMessageType.AddFriend) {
                AddFriendNotify attachData = (AddFriendNotify) systemMessage.getAttachObject();
                if (attachData != null && attachData.getEvent() == AddFriendNotify.Event.RECV_ADD_FRIEND_VERIFY_REQUEST) {//TODO

                }
            }
        }
    };

    public boolean deleteRecentContact(String rContactId) {
        return recentContactObserver.deleteRecentContact(rContactId);
    }

    public void logout() {

        NIMClient.getService(AuthService.class).logout();//退出服务

        registerObserver(false);//取消登录注册
        TeamListService.getInstance().clear();//群清理
        // 清理缓存&注销监听&清除状态
        DataCacheManager.clearDataCache();
        account = null;
        token = null;
        LoginSyncDataStatusObserver.getInstance().reset();
    }

    public void startSystemMsgUnreadCount() {
        registerSystemMsgUnreadCount(true);
        int unread = NIMClient.getService(SystemMessageService.class).querySystemMessageUnreadCountBlock();
        ReactCache.emit(ReactCache.observeUnreadCountChange, Integer.toString(unread));
    }

    boolean hasRegisterSystemMsgUnreadCount;
    private Observer<Integer> sysMsgUnreadCountChangedObserver = new Observer<Integer>() {
        @Override
        public void onEvent(Integer unreadCount) {
            int unread = unreadCount == null ? 0 : unreadCount;
            ReactCache.emit(ReactCache.observeUnreadCountChange, Integer.toString(unread));
        }
    };

    public void registerSystemMsgUnreadCount(boolean register) {
        if (hasRegisterSystemMsgUnreadCount && register) {
            return;
        }
        hasRegisterSystemMsgUnreadCount = register;
        NIMClient.getService(SystemMessageObserver.class).observeUnreadCountChange(sysMsgUnreadCountChangedObserver, register);
    }

}
