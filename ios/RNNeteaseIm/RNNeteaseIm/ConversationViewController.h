//
//  ConversationViewController.h
//  NIM
//
//  Created by Dowin on 2017/5/5.
//  Copyright © 2017年 Dowin. All rights reserved.
//

#import <UIKit/UIKit.h>
//#import "NIMModel.h"
#import "ImConfig.h"

typedef void(^Success)(id param);
typedef void(^Errors)(id erro);
@interface ConversationViewController : UIViewController<NIMChatManagerDelegate,NIMConversationManagerDelegate>

+(instancetype)initWithConversationViewController;
-(void)localSession:(NSInteger)index cerrentmessageId:(NSString *)currentMessageID success:(Success)succe err:(Errors)err;
-(void)startSession:(NSString *)sessionID withType:(NSString *)type options:(nonnull  NSDictionary *)options;
-(void)stopSession;
//XX
-(void)startChatMsg;
-(void)stopChatMsg;
//-(void)sendAudioRecode:(NSString *)filePath;
/**
 *  会话页详细配置
 */
//取消录音
- (void)onCancelRecording;
//结束录音
- (void)onStopRecording;
//开始录音
- (void)onStartRecording;
//发送文本，并指定@用户（@仅适用于群组）
-(void)sendMessage:(NSString *)mess andApnsMembers:(NSArray *)members apns:(nonnull  NSString *)apns;
//发送图片
-(void)sendImageMessages:(  NSString *)path   displayName:(  NSString *)displayName apns:(nonnull  NSString *)apns;
//发送音频
-(void)sendAudioMessage:(  NSString *)file duration:(  NSString *)duration apns:(nonnull  NSString *)apns;
//发送视频
-(void)sendVideoMessage:(  NSString *)path duration:(  NSString *)duration width:(  NSString *)width height:(  NSString *)height displayName:(  NSString *)displayName apns:(nonnull  NSString *)apns;
//发送自定义消息
-(void)sendCustomMessage:(NSDictionary *)dataDict apns:(nonnull  NSString *)apns;
//发送地理位置消息
-(void)sendLocationMessage:(  NSString *)latitude longitude:(  NSString *)longitude address:( NSString *)address apns:(nonnull  NSString *)apns;
//X
//发送提醒消息
-(void)sendTipMessage:(NSString *)contactId content:(NSString *)content apns:(nonnull  NSString *)apns;
//发送红包消息
- (void)sendRedPacketMessage:(NSString *)type comments:(NSString *)comments serialNo:(NSString *)serialNo;

//X
-(void)sendRTCCallNotice:(NSDictionary *)options;
+(void)sendCustomNotice:(NSDictionary *)options payload:(NSDictionary *)payload;
//x
-(void)saveRTCCallMessage:(NSDictionary *)options;
//x
-(void)sendRTCCallMessage:(NSDictionary *)options;

//发送转账消息
- (void)sendBankTransferMessage:(NSString *)amount comments:(NSString *)comments serialNo:(NSString *)serialNo;
//发送拆红包消息
- (void)sendRedPacketOpenMessage:(NSString *)sendId hasRedPacket:(NSString *)hasRedPacket serialNo:(NSString *)serialNo;
//发送名片消息
- (void)sendCardMessage:(int)type sessionId:(NSString *)sessionId name:(NSString *)name imgPath:(NSString *)strImgPath;

-(void)sendCardMessage:(NSDictionary *)options;
-(void)sendCustomMessage:(NSDictionary *)options;

//转发消息
-(void)forwardMessage:(NSString *)messageId sessionId:(NSString *)sessionId sessionType:(NSString *)sessionType content:(NSString *)content success:(Success)succe;

//本地历史记录
-(void)localSessionList:(NSString *)sessionId sessionType:(NSString *)sessionType timeLong:(NSString *)timeLong direction:(NSString *)direction limit:(NSString *)limit asc:(BOOL)asc success:(Success)succe;
//撤回消息
-(void)revokeMessage:(NSString *)messageId success:(Success)succe;
//开始播放录音
- (void)play:(NSString *)filepath;
//停止播放
- (void)stopPlay;
//好友消息提醒
-(void)muteMessage:(NSString *)contactId mute:(NSString *)mute Succ:(Success)succ Err:(Errors)err;
//清空本地聊天记录
-(void)clearMsg:(NSString *)contactId type:(NSString *)type;
//删除一条信息
-(void)deleteMsg:(NSString *)messageId;
//麦克风权限
- (void)onTouchVoiceSucc:(Success)succ Err:(Errors)err;
//更新录音消息为已播放
- (void)updateAudioMessagePlayStatus:(NSString *)messageID;

//获得撤回内容
//- (NSDictionary *)tipOnMessageRevoked:(id)message;
- (NSMutableDictionary *)tipOnMessageRevoked:(NIMMessage*)message session:(NIMSession*)session isSelf:(BOOL) isSelf messageFromUserId:(NSString *)messageFromUserId;
//更具提示生成撤回消息
- (NIMMessage *)msgWithTip:(NSString *)tip;
//重发消息
- (void)resendMessage:(NSString *)messageID;
+ (NSMutableDictionary *)getTipMessageExtend:(NIMMessage *)message;
@end
