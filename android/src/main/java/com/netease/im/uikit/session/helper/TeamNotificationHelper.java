package com.netease.im.uikit.session.helper;

import android.text.TextUtils;

import com.facebook.react.bridge.WritableMap;
import com.facebook.react.bridge.WritableNativeMap;
import com.netease.im.IMApplication;
import com.netease.im.R;
import com.netease.im.uikit.cache.TeamDataCache;
import com.netease.nimlib.sdk.msg.attachment.NotificationAttachment;
import com.netease.nimlib.sdk.msg.constant.SessionTypeEnum;
import com.netease.nimlib.sdk.msg.model.IMMessage;
import com.netease.nimlib.sdk.team.constant.TeamAllMuteModeEnum;
import com.netease.nimlib.sdk.team.constant.TeamFieldEnum;
import com.netease.nimlib.sdk.team.constant.TeamTypeEnum;
import com.netease.nimlib.sdk.team.constant.VerifyTypeEnum;
import com.netease.nimlib.sdk.team.model.MemberChangeAttachment;
import com.netease.nimlib.sdk.team.model.MuteMemberAttachment;
import com.netease.nimlib.sdk.team.model.Team;
import com.netease.nimlib.sdk.team.model.UpdateTeamAttachment;

import java.util.List;
import java.util.Map;

/**
 * 系统消息描述文本构造器。主要是将各个系统消息转换为显示的文本内容。<br>
 * Created by huangjun on 2015/3/11.
 */
public class TeamNotificationHelper {
//    private static ThreadLocal<String> teamId = new ThreadLocal<>();

//    public static String getMsgShowText(final IMMessage message) {
//        String content = "";
//        String messageTip = message.getMsgType().getSendMessageTip();
//        if (messageTip.length() > 0) {
//            content += "[" + messageTip + "]";
//        } else {
//            if (message.getSessionType() == SessionTypeEnum.Team && message.getAttachment() != null) {
//                content += getTeamNotificationText(message, message.getSessionId());
//            } else {
//                content += message.getContent();
//            }
//        }
//
//        return content;
//    }
//
//    public static String getTeamNotificationText(IMMessage message, String tid) {
//        return getTeamNotificationText(message.getSessionId(), message.getFromAccount(), (NotificationAttachment) message.getAttachment());
//    }
//
//    public static String getTeamNotificationText(String tid, String fromAccount, NotificationAttachment attachment) {
////        teamId.set(tid);
//        String text = buildNotification(tid, fromAccount, attachment);
////        teamId.set(null);
//        return text;
//    }

    public static WritableMap getTeamNotificationOptions(String tid, String fromAccount, NotificationAttachment attachment) {
        WritableMap option = new WritableNativeMap();
        String text = buildNotification(option, tid, fromAccount, attachment);
//        teamId.set(null);
        option.putString("msgType", "notification");
        option.putString("notificationType", "team");
        option.putString("tipMsg", text);
        return option;
    }

    private static String buildNotification(WritableMap option, String tid, String fromAccount, NotificationAttachment attachment) {
        String text = "";
        String operationType;
        String operationTag = "";
        WritableMap format = new WritableNativeMap();
        Team team = TeamDataCache.getInstance().getTeamById(tid);
        String source = TeamDataCache.getInstance().getTeamMemberDisplayNameYou(tid, fromAccount);
        String teamName = team.getType() == TeamTypeEnum.Advanced ? "team_type_group" : "team_type_normal";

        format.putString("teamName", teamName);
        format.putString("source", source);
        switch (attachment.getType()) {
            case InviteMember:
                buildInviteMemberNotification(format, team, ((MemberChangeAttachment) attachment), fromAccount);
                operationType = "invite";
                break;
            case KickMember:
                operationType = "kick";
                buildKickMemberNotification(format, team, ((MemberChangeAttachment) attachment));
                break;
            case LeaveTeam:
                operationType = "leave";
//                text = buildLeaveTeamNotification(team, fromAccount);
                break;
            case DismissTeam:
//                text = buildDismissTeamNotification(option, tid, fromAccount);
                operationType = "dismiss";
                break;
            case UpdateTeam:
                operationType = "update";
                operationTag = buildUpdateTeamNotification(format, tid, fromAccount, (UpdateTeamAttachment) attachment);
                break;
            case PassTeamApply:
                operationType = "apply_pass_invite";
                buildManagerPassTeamApplyNotification(format, tid, (MemberChangeAttachment) attachment);
                break;
            case TransferOwner:
                operationType = "transfer_owner";
                buildTransferOwnerNotification(format, tid, fromAccount, (MemberChangeAttachment) attachment);
                break;
            case AddTeamManager:
                operationType = "add_manager";
                buildAddTeamManagerNotification(format, tid, (MemberChangeAttachment) attachment);
                break;
            case RemoveTeamManager:
                operationType = "remove_manager";
                buildRemoveTeamManagerNotification(format, tid, (MemberChangeAttachment) attachment);
                break;
            case AcceptInvite:
                operationType = "accept_invitation";
                buildAcceptInviteNotification(format, tid, fromAccount, (MemberChangeAttachment) attachment);
                break;
            case MuteTeamMember:
                operationType = "mute";
                MuteMemberAttachment muteMemberAttachment = (MuteMemberAttachment) attachment;
                operationTag = muteMemberAttachment.isMute() ? "enabled" : "disabled";

//                format.putArray();
                buildMuteTeamNotification(format, tid, muteMemberAttachment);
                break;
            default:
                operationType = attachment.getType().name();
                text = getTeamMemberDisplayName(tid, fromAccount) + ": unknown message";
                break;
        }
//        format.putString("firstTarget", firstTarget);
        option.putMap("format", format);
        option.putString("operationTag", operationTag);
        option.putString("operationType", operationType);
        return text;
    }

    private static String getTeamMemberDisplayName(String tid, String account) {
        return TeamDataCache.getInstance().getTeamMemberDisplayNameYou(tid, account);
    }

    private static String buildMemberListString(String tid, List<String> members, String fromAccount) {
        StringBuilder sb = new StringBuilder();
        for (String account : members) {
            if (!TextUtils.isEmpty(fromAccount) && fromAccount.equals(account)) {
                continue;
            }
            sb.append(getTeamMemberDisplayName(tid, account));
            sb.append(",");
        }
        sb.deleteCharAt(sb.length() - 1);

        return sb.toString();
    }

    private static void buildInviteMemberNotification(WritableMap format, Team team, MemberChangeAttachment a, String fromAccount) {
        String firstTarget = buildMemberListString(team.getId(), a.getTargets(), fromAccount);
        format.putString("firstTarget", firstTarget);
        format.putInt("targets", a.getTargets().size());

//        StringBuilder sb = new StringBuilder();
//        String selfName = getTeamMemberDisplayName(team.getId(), fromAccount);
//
//        sb.append(selfName);
//        sb.append("邀请 ");
//        sb.append(firstTarget);
//        if (team.getType() == TeamTypeEnum.Advanced) {
//            sb.append(" 加入群");
//        } else {
//            sb.append(" 加入讨论组");
//        }
//
//        return sb.toString();
    }

    private static void buildKickMemberNotification(WritableMap format, Team team, MemberChangeAttachment a) {
        String firstTarget = buildMemberListString(team.getId(), a.getTargets(), null);
        format.putString("firstTarget", firstTarget);
        format.putInt("targets", a.getTargets().size());

//        StringBuilder sb = new StringBuilder();
//        sb.append(buildMemberListString(team.getId(), a.getTargets(), null));
//
//        if (team.getType() == TeamTypeEnum.Advanced) {
//            sb.append(" 已被移出群");
//        } else {
//            sb.append(" 已被移出讨论组");
//        }
//
//
//        return sb.toString();
    }

    private static String buildLeaveTeamNotification(Team team, String fromAccount) {
        String tip;
        if (team.getType() == TeamTypeEnum.Advanced) {
            tip = " 离开了群";
        } else {
            tip = " 离开了讨论组";
        }
        return getTeamMemberDisplayName(team.getId(), fromAccount) + tip;
    }

    private static String buildDismissTeamNotification(WritableMap option, String tid, String fromAccount) {
        return getTeamMemberDisplayName(tid, fromAccount) + " 解散了群";
    }

    private static String buildUpdateTeamNotification(WritableMap format, String tid, String account, UpdateTeamAttachment a) {

        String operationTag = "";
//        StringBuilder sb = new StringBuilder();
        for (Map.Entry<TeamFieldEnum, Object> field : a.getUpdatedFields().entrySet()) {
            if (field.getKey() == TeamFieldEnum.Name) {
                operationTag = "name";
                format.putString("newName", field.getValue().toString());
//                sb.append("名称被更新为 " + field.getValue());
            } else if (field.getKey() == TeamFieldEnum.Introduce) {
//                sb.append("群介绍被更新为 " + field.getValue());
                operationTag = "intro";
                format.putString("intro", field.getValue().toString());
            } else if (field.getKey() == TeamFieldEnum.Announcement) {
                operationTag = "announcement";
//                sb.append(TeamDataCache.getInstance().getTeamMemberDisplayNameYou(tid, account) + " 修改了群公告");
            } else if (field.getKey() == TeamFieldEnum.VerifyType) {
                operationTag = "join_mode";

                VerifyTypeEnum type = (VerifyTypeEnum) field.getValue();
//                String authen = "群身份验证权限更新为";
                String join_mode = "群身份验证权限更新为";
                if (type == VerifyTypeEnum.Free) {
                    join_mode = "free";
//                    sb.append(authen + IMApplication.getContext().getString(R.string.team_allow_anyone_join));
                } else if (type == VerifyTypeEnum.Apply) {
                    join_mode = "apply";
//                    sb.append(authen + IMApplication.getContext().getString(R.string.team_need_authentication));
                } else {
                    join_mode = "not_allow";
//                    sb.append(authen + IMApplication.getContext().getString(R.string.team_not_allow_anyone_join));
                }
                format.putString("join_mode", join_mode);
            } else if (field.getKey() == TeamFieldEnum.Extension) {
                operationTag = "extension";
                format.putString("extension", field.getValue().toString());
//                sb.append("群扩展字段被更新为 " + field.getValue());
            } else if (field.getKey() == TeamFieldEnum.Ext_Server_Only) {
                operationTag = "ext_server";
                format.putString("ext_server", field.getValue().toString());
//                sb.append("群扩展字段(服务器)被更新为 " + field.getValue());
            } else if (field.getKey() == TeamFieldEnum.ICON) {
//                sb.append("群头像已更新");
                operationTag = "avatar";
            } else if (field.getKey() == TeamFieldEnum.InviteMode) {
                operationTag = "invite_mode";
                format.putString("invite_mode", field.getValue().toString());
//                sb.append("群邀请他人权限被更新为 " + field.getValue());
            } else if (field.getKey() == TeamFieldEnum.TeamUpdateMode) {
                operationTag = "update_info_mode";
                format.putString("update_info_mode", field.getValue().toString());
//                sb.append("群资料修改权限被更新为 " + field.getValue());
            } else if (field.getKey() == TeamFieldEnum.BeInviteMode) {
                operationTag = "be_invite_mode";
                format.putString("be_invite_mode", field.getValue().toString());
//                sb.append("群被邀请人身份验证权限被更新为 " + field.getValue());
            } else if (field.getKey() == TeamFieldEnum.TeamExtensionUpdateMode) {
                operationTag = "update_extension_mode";
                format.putString("update_extension_mode", field.getValue().toString());
//                sb.append("群扩展字段修改权限被更新为 " + field.getValue());
            } else if (field.getKey() == TeamFieldEnum.AllMute) {

//                format.putString("update_extension_mode", field.getValue().toString());

                TeamAllMuteModeEnum teamAllMuteModeEnum = (TeamAllMuteModeEnum) field.getValue();
                if (teamAllMuteModeEnum == TeamAllMuteModeEnum.Cancel) {
//                    sb.append("取消群全员禁言");
                    operationTag = "mute_disabled";
                } else {
                    operationTag = "mute_enabled";
//                    sb.append("群全员禁言");
                }
            } else {
                format.putString("update_key", field.getKey().toString());
                format.putString("update_value", field.getValue().toString());
//                sb.append("群" + field.getKey() + "被更新为 " + field.getValue());
            }
//            sb.append("\r\n");
        }
//        if (sb.length() < 2) {
//            return "未知通知";
//        }
        return operationTag;
//        return sb.delete(sb.length() - 2, sb.length()).toString();
    }

    private static void buildManagerPassTeamApplyNotification(WritableMap format, String tid, MemberChangeAttachment a) {
        String firstTarget = buildMemberListString(tid, a.getTargets(), null);
        format.putString("firstTarget", firstTarget);
        format.putInt("targets", a.getTargets().size());

//        StringBuilder sb = new StringBuilder();
//        sb.append("管理员通过用户 ");
//        sb.append(buildMemberListString(tid, a.getTargets(), null));
//        sb.append(" 的入群申请");
//
//        return sb.toString();
    }

    private static void buildTransferOwnerNotification(WritableMap format, String tid, String from, MemberChangeAttachment a) {
        String firstTarget = buildMemberListString(tid, a.getTargets(), null);
        format.putString("firstTarget", firstTarget);
        format.putInt("targets", a.getTargets().size());
//
//        StringBuilder sb = new StringBuilder();
//        sb.append(getTeamMemberDisplayName(tid, from));
//        sb.append(" 将群转移给 ");
//        sb.append(buildMemberListString(tid, a.getTargets(), null));
//
//        return sb.toString();
    }

    private static void buildAddTeamManagerNotification(WritableMap format, String tid, MemberChangeAttachment a) {
        String firstTarget = buildMemberListString(tid, a.getTargets(), null);
        format.putString("firstTarget", firstTarget);
        format.putInt("targets", a.getTargets().size());

//        StringBuilder sb = new StringBuilder();
//
//        sb.append(buildMemberListString(tid, a.getTargets(), null));
//        sb.append(" 被任命为管理员");
//
//        return sb.toString();
    }

    private static void buildRemoveTeamManagerNotification(WritableMap format, String tid, MemberChangeAttachment a) {
        String firstTarget = buildMemberListString(tid, a.getTargets(), null);
        format.putString("firstTarget", firstTarget);
        format.putInt("targets", a.getTargets().size());
//
//        StringBuilder sb = new StringBuilder();
//
//        sb.append(buildMemberListString(tid, a.getTargets(), null));
//        sb.append(" 被撤销管理员身份");
//
//        return sb.toString();
    }

    private static void buildAcceptInviteNotification(WritableMap format, String tid, String from, MemberChangeAttachment a) {
        String firstTarget = buildMemberListString(tid, a.getTargets(), null);
        format.putString("firstTarget", firstTarget);
        format.putInt("targets", a.getTargets().size());

//        StringBuilder sb = new StringBuilder();
//
//        sb.append(getTeamMemberDisplayName(tid, from));
//        sb.append(" 接受了 ").append(buildMemberListString(tid, a.getTargets(), null)).append(" 的入群邀请");
//
//        return sb.toString();
    }

    private static void buildMuteTeamNotification(WritableMap format, String tid, MuteMemberAttachment a) {
        String firstTarget = buildMemberListString(tid, a.getTargets(), null);
        format.putString("firstTarget", firstTarget);
        format.putInt("targets", a.getTargets().size());

//        StringBuilder sb = new StringBuilder();
//
//        sb.append(buildMemberListString(tid, a.getTargets(), null));
//        sb.append("被管理员");
//        sb.append(a.isMute() ? "禁言" : "解除禁言");
//
//        return sb.toString();
    }
}
