package com.netease.im;

import com.netease.nimlib.sdk.msg.constant.SessionTypeEnum;
import com.netease.nimlib.sdk.msg.model.IMMessage;

public class NIMSession {
    public String sessionId;
    public SessionTypeEnum sessionType;

    private NIMSession(String sessionId, SessionTypeEnum sessionType) {
        this.sessionId = sessionId;
        this.sessionType = sessionType;
    }

    public static NIMSession make(String sessionId, SessionTypeEnum sessionType) {
        NIMSession session = new NIMSession(sessionId, sessionType);
        return session;
    }

    public static NIMSession makeFromIMMessage(IMMessage imMessage) {
        NIMSession session = new NIMSession(imMessage.getSessionId(), imMessage.getSessionType());
        return session;
    }
}
