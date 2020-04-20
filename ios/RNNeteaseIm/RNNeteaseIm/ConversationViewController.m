//
//  ConversationViewController.m
//  NIM
//
//  Created by Dowin on 2017/5/5.
//  Copyright © 2017年 Dowin. All rights reserved.
//

#import "ConversationViewController.h"
#import <Photos/PhotosTypes.h>
#import "NIMMessageMaker.h"
#import "ContactViewController.h"
#import "NIMKitLocationPoint.h"

#import <AVFoundation/AVFoundation.h>
//#import "NIMKitMediaFetcher.h"

#define NTESNotifyID        @"id"
#define NTESCustomContent  @"content"

#define NTESCommandTyping  (1)
#define NTESCustom         (2)
#import "NSDictionary+NTESJson.h"
@interface ConversationViewController ()<NIMMediaManagerDelegate,NIMMediaManagerDelegate,NIMSystemNotificationManagerDelegate>{
    NSString *_sessionID;
    NSString *_type;
    NSInteger _index;
    //    NIMSession *_session;
    NSMutableArray *_sessionArr;
    
}
@property (nonatomic,strong) AVAudioPlayer *player; //播放提示音
@property (nonatomic,strong) AVAudioPlayer *redPacketPlayer; //播放提示音
@property (nonatomic,strong) NIMSession *_session;
//@property (nonatomic,strong) NIMKitMediaFetcher *mediaFetcher;

@end

@implementation ConversationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
}


+(instancetype)initWithConversationViewController{
    static ConversationViewController *conVC = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        conVC = [[ConversationViewController alloc]init];
        
    });
    return conVC;
}

- (instancetype)init {
    self = [super init];
    if(self) {
        NSURL *url = [[NSBundle mainBundle] URLForResource:@"message" withExtension:@"wav"];
        _player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
        _player.volume = 1.0;
        NSURL *redPackUrl = [[NSBundle mainBundle] URLForResource:@"packet_tip" withExtension:@"wav"];
        _redPacketPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:redPackUrl error:nil];
        _redPacketPlayer.volume = 1.0;
        
        //        id<NIMCustomAttachmentCoding> decoder = [[DWCustomAttachmentDecoder alloc] init];
        
        
        
    }
    return self;
}

//- (NIMKitMediaFetcher *)mediaFetcher
//{
//    if (!_mediaFetcher) {
//        _mediaFetcher = [[NIMKitMediaFetcher alloc] init];
//    }
//    return _mediaFetcher;
//}

-(void)startSession:(NSString *)sessionID withType:(NSString *)type{
    _sessionID = sessionID;
    _type = type;
    self._session = [NIMSession session:_sessionID type:[_type integerValue]];
    //    _session = [NIMSession session:_sessionID type:[_type integerValue]];
    _sessionArr = [NSMutableArray array];
    [self addListener];
}


//本地历史记录
-(void)localSessionList:(NSString *)sessionId sessionType:(NSString *)sessionType timeLong:(NSString *)timeLong direction:(NSString *)direction limit:(NSString *)limit asc:(BOOL)asc success:(Success)succe{
    // NIMMessageSearchOption *option = [[NIMMessageSearchOption alloc]init];
}

//重发消息
- (void)resendMessage:(NSString *)messageID{
    NSArray *currentMessage = [[[NIMSDK sharedSDK] conversationManager] messagesInSession:self._session messageIds:@[messageID] ];
    NIMMessage *currentM = currentMessage[0];
    NSString *isFriend = [currentM.localExt objectForKey:@"isFriend"];
    if ([isFriend length]) {
        
    }else{
        if (currentM.isReceivedMsg) {
            [[[NIMSDK sharedSDK] chatManager] fetchMessageAttachment:currentM error:nil];
        }else{
            [[[NIMSDK sharedSDK] chatManager] resendMessage:currentM error:nil];
        }
    }
}
//聊天界面历史记录
-(void)localSession:(NSInteger)index cerrentmessageId:(NSString *)currentMessageID success:(Success)succe err:(Errors)err{
    _index = index;
    [[NIMSDK sharedSDK].conversationManager markAllMessagesReadInSession:self._session];
    if (currentMessageID.length != 0) {
        
        NSArray *currentMessage = [[[NIMSDK sharedSDK] conversationManager] messagesInSession:self._session messageIds:@[currentMessageID] ];
        NIMMessage *currentM = currentMessage[0];
        NSArray *messageArr =  [[[NIMSDK sharedSDK] conversationManager]messagesInSession:self._session message:currentM limit: index];
        if (messageArr.count != 0) {
            succe([self setTimeArr:messageArr]);
        }else{
            
            err(@"暂无更多");
        }
        
    }
    else{
        NSArray *messageArr =  [[[NIMSDK sharedSDK] conversationManager]messagesInSession:self._session message:nil limit: index];
        if ([self setTimeArr:messageArr].count != 0) {
            NSMutableDictionary *dic = [[self setTimeArr:messageArr] objectAtIndex:[self setTimeArr:messageArr].count - 1];
            [[NSUserDefaults standardUserDefaults]setObject:[dic objectForKey:@"time"] forKey:@"timestamp"];
        }
        succe([self setTimeArr:messageArr]);
    }
}
//更新录音消息为已播放
- (void)updateAudioMessagePlayStatus:(NSString *)messageID{
    NSArray *messages = [[[NIMSDK sharedSDK] conversationManager] messagesInSession:self._session messageIds:@[messageID] ];
    if (messages.count) {
        NIMMessage *tmpMessage = messages.firstObject;
        tmpMessage.isPlayed = YES;
    }
}


+ (NSMutableDictionary *)getTipMessageExtend:(NIMMessage *)message{
    NSMutableDictionary *extend = [NSMutableDictionary dictionary];
    [extend setObject:message.text==nil?@"":message.text forKey:@"tipMsg"];
    //    NSMutableDictionary *options = [NSMutableDictionary dictionary];
    NSString *tipType = @"";
    
    if (message.remoteExt!=nil) {
        [extend setObject:message.remoteExt forKey:@"options"];
        NSString *_tipType = [message.remoteExt objectForKey:@"tipType"];
        if (_tipType!= nil){
            tipType =_tipType;
        }
    }
    
    
    if (message.localExt!=nil) {
        [extend setObject:message.localExt forKey:@"options"];
        NSString *_tipType = [message.localExt objectForKey:@"tipType"];
        if (_tipType!= nil){
            tipType =_tipType;
        }
    }
    
    [extend setObject:tipType forKey:@"tipType"];
    //   [extend setObject:options forKey:@"options"];
    return extend ;
}

-(NSMutableArray *)setTimeArr:(NSArray *)messageArr{
    NSMutableArray *sourcesArr = [NSMutableArray array];
    for (NIMMessage *message in messageArr) {
        NSMutableDictionary *dic = [NSMutableDictionary dictionary];
        NSMutableDictionary *fromUser = [NSMutableDictionary dictionary];
        NIMUser   *messageUser = [[NIMSDK sharedSDK].userManager userInfo:message.from];
        [fromUser setObject:[NSString stringWithFormat:@"%@",messageUser.userInfo.avatarUrl] forKey:@"avatar"];
        NSString *strAlias = messageUser.alias;
        if (strAlias.length) {
            [fromUser setObject:strAlias forKey:@"name"];
        }else if(messageUser.userInfo.nickName.length){
            [fromUser setObject:[NSString stringWithFormat:@"%@",messageUser.userInfo.nickName] forKey:@"name"];
        }else{
            [fromUser setObject:[NSString stringWithFormat:@"%@",messageUser.userId] forKey:@"name"];
        }
        [fromUser setObject:[NSString stringWithFormat:@"%@", message.from] forKey:@"_id"];
        [fromUser setObject:[NSString stringWithFormat:@"%@", message.from] forKey:@"id"];
        NSArray *key = [fromUser allKeys];
        for (NSString *tem  in key) {
            if ([[fromUser objectForKey:tem] isEqualToString:@"(null)"]) {
                [fromUser setObject:@"" forKey:tem];
            }
        }
        [dic setObject:[NSString stringWithFormat:@"%@", message.text] forKey:@"text"];
        [dic setObject:[NSString stringWithFormat:@"%@", message.session.sessionId] forKey:@"sessionId"];
        [dic setObject:[NSString stringWithFormat:@"%ld", message.session.sessionType] forKey:@"sessionType"];
        switch (message.deliveryState) {
            case NIMMessageDeliveryStateFailed:
                [dic setObject:@"send_failed" forKey:@"status"];
                break;
            case NIMMessageDeliveryStateDelivering:
                [dic setObject:@"send_going" forKey:@"status"];
                break;
            case NIMMessageDeliveryStateDeliveried:
                [dic setObject:@"send_succeed" forKey:@"status"];
                break;
            default:
                [dic setObject:@"send_failed" forKey:@"status"];
                break;
        }
        NSString *isFriend = [message.localExt objectForKey:@"isFriend"];
        if ([isFriend length]) {
            if ([isFriend isEqualToString:@"NO"]) {
                [dic setObject:@"send_failed" forKey:@"status"];
            }
        }
        [dic setObject: [NSNumber numberWithBool:message.isOutgoingMsg] forKey:@"isOutgoing"];
        [dic setObject:[NSString stringWithFormat:@"%f", message.timestamp] forKey:@"timeString"];
        [dic setObject:[NSNumber numberWithBool:NO] forKey:@"isShowTime"];
        [dic setObject:[NSString stringWithFormat:@"%@", message.messageId] forKey:@"msgId"];
        NSLog(@"NIMMessageTypeCustom：message.messageType %ld",message.messageType);
        if (message.messageType == NIMMessageTypeText) {
            [dic setObject:@"text" forKey:@"msgType"];
        }else if (message.messageType  == NIMMessageTypeImage) {
            [dic setObject:@"image" forKey:@"msgType"];
            NIMImageObject *object = message.messageObject;
            [dic setObject:[NSString stringWithFormat:@"%@", [object thumbPath]] forKey:@"mediaPath"];
            NSMutableDictionary *imgObj = [NSMutableDictionary dictionary];
            [imgObj setObject:[NSString stringWithFormat:@"%@", [object thumbPath] ] forKey:@"thumbPath"];
            [imgObj setObject:[NSString stringWithFormat:@"%@", [object thumbUrl] ] forKey:@"thumbUrl"];
            [imgObj setObject:[NSString stringWithFormat:@"%@",[object url] ] forKey:@"url"];
            [imgObj setObject:[NSString stringWithFormat:@"%@",[object displayName] ] forKey:@"displayName"];
            [imgObj setObject:[NSString stringWithFormat:@"%f",[object size].height] forKey:@"imageHeight"];
            [imgObj setObject:[NSString stringWithFormat:@"%f",[object size].width] forKey:@"imageWidth"];
            [imgObj setObject:[NSString stringWithFormat:@"%lld",[object fileLength] ] forKey:@"size"];
            [dic setObject:imgObj forKey:@"extend"];
        }else if(message.messageType == NIMMessageTypeAudio){
            [dic setObject:@"voice" forKey:@"msgType"];
            NIMAudioObject *object = message.messageObject;
            [dic setObject:[NSString stringWithFormat:@"%@",object.path] forKey:@"mediaPath"];
            [dic setObject:[NSString stringWithFormat:@"%@",object.url] forKey:@"url"];
            [dic setObject:[NSNumber numberWithInteger:object.duration] forKey:@"duration"];
            NSMutableDictionary *voiceObj = [NSMutableDictionary dictionary];
            [voiceObj setObject:[NSString stringWithFormat:@"%@", [object url]] forKey:@"url"];
            [voiceObj setObject:[NSString stringWithFormat:@"%zd",(object.duration/1000)] forKey:@"duration"];
            [voiceObj setObject:[NSNumber  numberWithBool:message.isPlayed] forKey:@"isPlayed"];
            [dic setObject:voiceObj forKey:@"extend"];
        }else if(message.messageType == NIMMessageTypeVideo ){
            [dic setObject:@"video" forKey:@"msgType"];
            NIMVideoObject *object = message.messageObject;
            
            [dic setObject:[NSString stringWithFormat:@"%@",object.url ] forKey:@"videoUrl"];
            [dic setObject:[NSString stringWithFormat:@"%@", object.displayName ] forKey:@"displayName"];
            [dic setObject:[NSString stringWithFormat:@"%@", object.coverUrl ] forKey:@"coverUrl"];
            [dic setObject:[NSString stringWithFormat:@"%ld",object.duration ] forKey:@"duration"];
            [dic setObject:[NSString stringWithFormat:@"%lld",object.fileLength] forKey:@"fileLength"];
            NSMutableDictionary *videoObj = [NSMutableDictionary dictionary];
            
            [videoObj setObject:[NSString stringWithFormat:@"%f",object.coverSize.height ] forKey:@"coverSizeHeight"];
            [videoObj setObject:[NSString stringWithFormat:@"%f", object.coverSize.width ] forKey:@"coverSizeWidth"];
            [videoObj setObject:[NSString stringWithFormat:@"%@", object.displayName ] forKey:@"displayName"];
            [videoObj setObject:[NSString stringWithFormat:@"%ld",object.duration ] forKey:@"duration"];
            [videoObj setObject:[NSString stringWithFormat:@"%lld",object.fileLength] forKey:@"fileLength"];
            [videoObj setObject:[NSString stringWithFormat:@"%@",object.url ] forKey:@"videoUrl"];
            [videoObj setObject:[NSString stringWithFormat:@"%@", object.coverUrl ] forKey:@"coverUrl"];
            [dic setObject:videoObj forKey:@"extend"];
            /*
             if([[NSFileManager defaultManager] fileExistsAtPath:object.coverPath]){
             [dic setObject:[NSString stringWithFormat:@"%@",object.coverPath] forKey:@"coverPath"];
             }else{
             //如果封面图下跪了，点进视频的时候再去下一把封面图
             [[NIMSDK sharedSDK].resourceManager download:object.coverUrl filepath:object.coverPath progress:nil completion:^(NSError *error) {
             if (!error) {
             [dic setObject:[NSString stringWithFormat:@"%@",object.coverPath] forKey:@"coverPath"];
             }
             }];
             }*/
            if ([[NSFileManager defaultManager] fileExistsAtPath:object.path]) {
                [dic setObject:[NSString stringWithFormat:@"%@",object.path] forKey:@"mediaPath"];
            }else{
                
                [[NIMObject initNIMObject] downLoadVideo:object Error:^(NSError *error) {
                    if (!error) {
                        [dic setObject:[NSString stringWithFormat:@"%@",object.path] forKey:@"mediaPath"];
                    }
                } progress:^(float progress) {
                    NSLog(@"视频下载进度%f",progress);
                }];
            }
        }else if(message.messageType == NIMMessageTypeLocation){
            [dic setObject:@"location" forKey:@"msgType"];
            NIMLocationObject *object = message.messageObject;
            NSMutableDictionary *locationObj = [NSMutableDictionary dictionary];
            [locationObj setObject:[NSString stringWithFormat:@"%f", object.latitude ] forKey:@"latitude"];
            [locationObj setObject:[NSString stringWithFormat:@"%f", object.longitude ] forKey:@"longitude"];
            [locationObj setObject:[NSString stringWithFormat:@"%@", object.title ] forKey:@"title"];
            [dic setObject:locationObj forKey:@"extend"];
            
        }else if(message.messageType == NIMMessageTypeTip){//提醒类消息
            [dic setObject:@"notification" forKey:@"msgType"];
            NSDictionary *notiObj = [ConversationViewController getTipMessageExtend:message];
            [dic setObject:notiObj forKey:@"extend"];
        }else if (message.messageType == NIMMessageTypeNotification) {
            [dic setObject:@"notification" forKey:@"msgType"];
            NSMutableDictionary *notiObj = [NSMutableDictionary dictionary];
            NIMNotificationObject *object = message.messageObject;
            switch (object.notificationType) {
                case NIMNotificationTypeTeam:
                case NIMNotificationTypeChatroom:
                {
                    //                    [notiObj setObject:[NIMKitUtil messageTipContent:message] forKey:@"tipMsg"];
                    //X
                    NSMutableDictionary *options = [NSMutableDictionary dictionary];
                    [notiObj setObject:[NIMKitUtil messageTipContent2:message result:options] forKey:@"tipMsg"];
                    [notiObj setObject:options forKey:@"options"];
                    break;
                }
                case NIMNotificationTypeNetCall:{
                    [notiObj setObject:[NIMKitUtil messageTipContent:message]forKey:@"tipMsg"];
                    break;
                }
                default:
                    break;
            }
            [dic setObject:notiObj forKey:@"extend"];
            
        }else if (message.messageType == NIMMessageTypeCustom) {
            NIMCustomObject *customObject = message.messageObject;
            DWCustomAttachment *obj = customObject.attachment;
            //            NSLog(@"NIMMessageTypeCustom：customObject %@ obj:%@",customObject,obj);
            if (obj) {
                //NSLog(@"NIMMessageTypeCustom：custType %ld dataDict:%@",obj.custType,obj.dataDict);
                [dic setObject:obj.custTypeStr forKey:@"custType"];
                [dic setObject:obj.dataDict forKey:@"extend"];
                
                switch (obj.custType) {
                    case CustomMessgeTypeRTCCall: //rtc_call
                    {
                        //                        [dic setObject:obj.dataDict forKey:@"extend"];
                        //                        [dic setObject:@"redpacket" forKey:@"custType"];
                        [dic setObject:@"rtcCall" forKey:@"msgType"];
                    }
                        break;
                    case CustomMessgeTypeRedpacket: //红包
                    {
                        //                        [dic setObject:obj.dataDict forKey:@"extend"];
                        //                        [dic setObject:@"redpacket" forKey:@"custType"];
                        [dic setObject:@"redpacket" forKey:@"msgType"];
                    }
                        break;
                    case CustomMessgeTypeBankTransfer: //转账
                    {
                        //                        [dic setObject:obj.dataDict  forKey:@"extend"];
                        //                        [dic setObject:@"transfer" forKey:@"custType"];
                        [dic setObject:@"transfer" forKey:@"msgType"];
                    }
                        break;
                    case CustomMessgeTypeRedPacketOpenMessage: //拆红包消息
                    {
                        NSDictionary *dataDict = [self dealWithData:obj.dataDict];
                        if (dataDict) {
                            [dic setObject:dataDict  forKey:@"extend"];
                            //                            [dic setObject:@"redpacketOpen" forKey:@"custType"];
                            [dic setObject:@"redpacketOpen" forKey:@"msgType"];
                        }else{
                            
                            continue;//终止本次循环
                        }
                    }
                        break;
                    case CustomMessgeTypeUrl: //链接
                    case CustomMessgeTypeAccountNotice: //账户通知，与账户金额相关变动
                    {
                        [dic setObject:[NSString stringWithFormat:@"%d",message.isRemoteRead] forKey:@"isRemoteRead"];
                        //                        [dic setObject:[NSString stringWithFormat:@"%ld", message.messageType] forKey:@"msgType"];
                        if (obj.custType == CustomMessgeTypeAccountNotice) {
                            //                            [dic setObject:obj.dataDict  forKey:@"extend"];
                            [dic setObject:@"account_notice" forKey:@"msgType"];
                        }else{
                            //                            [dic setObject:obj.dataDict  forKey:@"extend"];
                            [dic setObject:@"url" forKey:@"msgType"];
                        }
                    }
                        break;
                    case CustomMessgeTypeBusinessCard://名片
                    {
                        //                        [dic setObject:obj.dataDict  forKey:@"extend"];
                        [dic setObject:@"card" forKey:@"msgType"];
                    }
                        break;
                    case CustomMessgeTypeCustom://自定义
                    {
                        //                        [dic setObject:obj.dataDict  forKey:@"extend"];
                        [dic setObject:@"custom" forKey:@"msgType"];
                    }
                        break;
                    default:
                    {
                        //                        [dic setObject:obj.dataDict  forKey:@"extend"];
                        [dic setObject:@"unknown" forKey:@"msgType"];
                    }
                        break;
                        
                }
            }
        }else{
            [dic setObject:@"unknown" forKey:@"msgType"];
            NSMutableDictionary *unknowObj = [NSMutableDictionary dictionary];
            [dic setObject:unknowObj  forKey:@"extend"];
        }
        [dic setObject:fromUser forKey:@"fromUser"];
        [sourcesArr addObject:dic];
    }
    
    return sourcesArr;
    
}
//取消录音
- (void)onCancelRecording
{
    [[NIMSDK sharedSDK].mediaManager cancelRecord];
}
//结束录音
- (void)onStopRecording
{
    
    [[NIMSDK sharedSDK].mediaManager stopRecord];
    
}
//开始录音
- (void)onStartRecording
{
    NIMAudioType type = NIMAudioTypeAAC;
    NSTimeInterval duration = 60.0;
    
    [[NIMSDK sharedSDK].mediaManager addDelegate:self];
    
    [[NIMSDK sharedSDK].mediaManager record:type
                                   duration:duration];
}
//开始播放录音
- (void)play:(NSString *)filepath{
    [[NIMSDK sharedSDK].mediaManager addDelegate:self];
    if (filepath) {
        [[NIMSDK sharedSDK].mediaManager play:filepath];
    }
}
//停止播放
- (void)stopPlay{
    [[NIMSDK sharedSDK].mediaManager stopPlay];
}
//发送录音
-(void)sendAudioMessage:(  NSString *)file duration:(  NSString *)duration apns:(nonnull  NSString *)apns{
    if (file) {
        NIMMessage *message = [NIMMessageMaker msgWithAudio:file andeSession:self._session apns:apns];
        if ([self isFriendToSendMessage:message]) {
            [[[NIMSDK sharedSDK] chatManager] sendMessage:message toSession:self._session error:nil];
        }
    }
}
//发送文字消息
-(void)sendMessage:(NSString *)mess andApnsMembers:(NSArray *)members  apns:(nonnull  NSString *)apns{
    NIMMessage *message = [NIMMessageMaker msgWithText:mess andApnsMembers:members andeSession:self._session apns:apns];
    //发送消息
    if ([self isFriendToSendMessage:message]) {
        [[NIMSDK sharedSDK].chatManager sendMessage:message toSession:self._session error:nil];
    }
}
//发送图片
-(void)sendImageMessages:(  NSString *)path  displayName:(  NSString *)displayName  apns:(nonnull  NSString *)apns{
    UIImage *img = [[UIImage alloc]initWithContentsOfFile:path];
    NIMMessage *message = [NIMMessageMaker msgWithImage:img andeSession:self._session apns:apns];
    //    NIMMessage *message = [NIMMessageMaker msgWithImagePath:path];
    if ([self isFriendToSendMessage:message]) {
        [[NIMSDK sharedSDK].chatManager sendMessage:message toSession:self._session error:nil];
    }
}

//发送视频
-(void)sendVideoMessage:(  NSString *)path duration:(  NSString *)duration width:(  NSString *)width height:(  NSString *)height displayName:(  NSString *)displayName  apns:(nonnull  NSString *)apns{
    //    __weak typeof(self) weakSelf = self;
    //    [self.mediaFetcher fetchMediaFromCamera:^(NSString *path, UIImage *image) {
    NIMMessage *message;
    //        if (image) {
    //            message = [NIMMessageMaker msgWithImage:image andeSession:self._session];
    //        }else{
    if ([path hasPrefix:@"file:///private"]) {
        path = [path stringByReplacingOccurrencesOfString:@"file:///private" withString:@""];
    }
    message = [NIMMessageMaker msgWithVideo:path andeSession:self._session apns:apns];
    //        }
    if ([self isFriendToSendMessage:message]) {
        [[NIMSDK sharedSDK].chatManager sendMessage:message toSession:self._session error:nil];
    }
    //    }];
}

//发送自定义消息
-(void)sendCustomMessage:(NSDictionary *)dataDict  apns:(nonnull  NSString *)apns{
    NSString *strW = [dataDict objectForKey:@"Width"] ? [NSString stringWithFormat:@"%@",[dataDict objectForKey:@"Width"]] : @"0";
    NSString *strH = [dataDict objectForKey:@"Height"] ? [NSString stringWithFormat:@"%@",[dataDict objectForKey:@"Height"]] : @"0";
    [dataDict setValue:strW forKey:@"Width"];
    [dataDict setValue:strH forKey:@"Height"];
    [self sendCustomMessage:CustomMessgeTypeCustom data:dataDict apns:apns];
}


//发送自定义消息2
-(void)sendCustomMessage:(NSInteger )custType data:(NSDictionary *)dataDict  apns:(nonnull  NSString *)apns{
    [self sendCustomMessage:custType data:dataDict toSession:self._session apns:apns];
}
//发送自定义消息3
-(void)sendCustomMessage:(NSInteger )custType data:(NSDictionary *)dataDict toSession:(NIMSession *)session  apns:(nonnull  NSString *)apns{
    NIMMessage *message;
    DWCustomAttachment *obj = [[DWCustomAttachment alloc]init];
    obj.custType = custType;
    obj.dataDict = dataDict;
    message = [NIMMessageMaker msgWithCustomAttachment:obj andeSession:session apns:apns];
    
    NIMMessageSetting *setting = [[NIMMessageSetting alloc]init];
    setting.shouldBeCounted = false;
    message.setting = setting;
    message.apnsContent = apns;
    
    
    if ([self isFriendToSendMessage:message toSession:session]) {
        [[NIMSDK sharedSDK].chatManager sendMessage:message toSession:session error:nil];
    }
}



-(void)saveCustomMessage:(NSInteger )custType data:(NSDictionary *)dataDict  apns:(nonnull  NSString *)apns{
    NIMMessage *message;
    DWCustomAttachment *obj = [[DWCustomAttachment alloc]init];
    obj.custType = custType;
    obj.dataDict = dataDict;
    message = [NIMMessageMaker msgWithCustomAttachment:obj andeSession:self._session apns:apns];
    
    //    message.from = [ self._session sessionId];
    //    message.text = @"aaaaa";
    
    //    [[NIMSDK sharedSDK].chatManager saveMessage:message forSession:self._session error:nil];
    [[NIMSDK sharedSDK].conversationManager saveMessage:message forSession:self._session completion:nil];
}

//发送地理位置消息
-(void)sendLocationMessage:(  NSString *)latitude longitude:(  NSString *)longitude address:(  NSString *)address  apns:(nonnull  NSString *)apns{
    NIMLocationObject *locaObj = [[NIMLocationObject alloc]initWithLatitude:[latitude doubleValue] longitude:[longitude doubleValue] title:address];
    NIMKitLocationPoint *locationPoint = [[NIMKitLocationPoint alloc]initWithLocationObject:locaObj];
    NIMMessage *message = [NIMMessageMaker msgWithLocation:locationPoint andeSession:self._session apns:apns];
    if ([self isFriendToSendMessage:message]) {
        [[NIMSDK sharedSDK].chatManager sendMessage:message toSession:self._session error:nil];
    }
}

//X
//发送提醒消息
-(void)sendTipMessage:(NSString *)contactId content:(NSString *)content  apns:(nonnull  NSString *)apns{
    NIMSession *session2  = [NIMSession session:contactId type:NIMSessionTypeP2P];
    
    // 获得文件附件对象
    NIMTipObject *object = [[NIMTipObject alloc] init];
    // 构造出具体消息并注入附件
    NIMMessage *message2 = [[NIMMessage alloc] init];
    message2.messageObject = object;
    message2.text = content;
    message2.apnsContent = apns;
    
    // 发送消息
    [[NIMSDK sharedSDK].chatManager sendMessage:message2 toSession:session2 error:nil];
}
//- (NIMKitMediaFetcher *)mediaFetcher
//{
//    if (!_mediaFetcher) {
//        _mediaFetcher = [[NIMKitMediaFetcher alloc] init];
//    }
//    return _mediaFetcher;
//}


#pragma mark - RTC

//发送自定义消息3
-(void)sendRTCCallMessage:(NSDictionary *)dataDict toSession:(NIMSession *)session shouldBeCounted:(BOOL )shouldBeCounted apns:(nonnull  NSString *)apns{
    NIMMessage *message;
    DWCustomAttachment *obj = [[DWCustomAttachment alloc]init];
    obj.custType = CustomMessgeTypeRTCCall;
    obj.dataDict = dataDict;
    message = [NIMMessageMaker msgWithCustomAttachment:obj andeSession:session apns:apns];
    
    NIMMessageSetting *setting = [[NIMMessageSetting alloc]init];
    setting.shouldBeCounted = shouldBeCounted;
    setting.apnsWithPrefix = YES;
    message.setting = setting;
    message.apnsContent = apns;
    
    if ([self isFriendToSendMessage:message toSession:session]) {
        [[NIMSDK sharedSDK].chatManager sendMessage:message toSession:session error:nil];
    }
}

-(void)sendRTCCallMessage:(NSDictionary *)options{
    NSString *sessionId = [options objectForKey:@"sessionId"];
    NSDictionary *data = [options jsonDict:@"data"];
    NSString *apns = [options objectForKey:@"apns"];
    BOOL shouldBeCounted = [options jsonBool:@"counted"];
    
    NIMSession *session = [NIMSession session:sessionId type:NIMSessionTypeP2P];
    [self sendRTCCallMessage:data toSession:session shouldBeCounted:shouldBeCounted apns:apns];
}

//发送RTC消息
-(void)saveRTCCallMessage:(NSDictionary *)options{
    
    NSString *sessionId = [options objectForKey:@"sessionId"];
    NSDictionary *data = [options jsonDict:@"data"];
    
    NIMSession *session = [NIMSession session:sessionId type:NIMSessionTypeP2P];
    
    NIMMessage *message;
    DWCustomAttachment *obj = [[DWCustomAttachment alloc]init];
    obj.custType = CustomMessgeTypeRTCCall;
    obj.dataDict = data;
    message = [NIMMessageMaker msgWithCustomAttachment:obj andeSession:session apns:@""];
    
    NIMMessageSetting *setting = [[NIMMessageSetting alloc]init];
    message.setting = setting;
    
    NSString *from = [options objectForKey:@"from"];
    if (from != nil) {
        message.from = from;
    }
    
    id counted = [options objectForKey:@"counted"];
    
    if (counted != nil && ([counted isKindOfClass:[NSString class]] ||
                           [counted isKindOfClass:[NSNumber class]])) {
        setting.shouldBeCounted = [counted boolValue];
    }
    else{
        setting.shouldBeCounted = false;
    }
    
    
    if ([self isFriendToSendMessage:message toSession:session]) {
        [[NIMSDK sharedSDK].conversationManager saveMessage:message forSession:session completion:nil];
    }
}

+(void)sendCustomNotice:(NSDictionary *)options payload:(NSDictionary *)payload{
     NSLog(@"sendCustomNotice: options: %@ payload: %@",options,payload);
    
    NIMSession *session = [NIMSession session:[options jsonString:@"sessionId"] type:[options jsonInteger:@"sessionType"]];
 
    NSString *content = [NIMMessageMaker jsonStringWithDictionary:payload];
    NIMCustomSystemNotification *notifi = [[NIMCustomSystemNotification alloc]initWithContent:content];
    notifi.sendToOnlineUsersOnly = [options jsonBool:@"sendToOnlineUsersOnly"];
    
    NIMCustomSystemNotificationSetting *setting = [[NIMCustomSystemNotificationSetting alloc]init];
    setting.shouldBeCounted = [options jsonBool:@"shouldBeCounted"];
    setting.apnsEnabled = [options jsonBool:@"apnsEnabled"];
    setting.apnsWithPrefix = [options jsonBool:@"apnsWithPrefix"];
    
    notifi.apnsContent = [options jsonString:@"apns"];
    
    NSString *apns_sound = [options jsonString:@"apns_sound"];
    notifi.apnsPayload = [NIMMessageMaker makeApnsPayload:[options jsonString:@"apnsType"] payloadData:payload sound:apns_sound];
    notifi.setting = setting;
    
    [[NIMSDK sharedSDK].systemNotificationManager sendCustomNotification:notifi toSession:session completion:nil];//发送自定义通知
}

-(void)sendRTCCallNotice:(NSDictionary *)options{
//    [self sendCustomNotice:@{} payload:[options objectForKey:@"data"]];
    NSMutableDictionary *mOptions = [options mutableCopy];
    NIMSession *session = [NIMSession session:[options jsonString:@"sessionId"] type:[options jsonInteger:@"sessionType"]];

    NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];
    [mOptions setObject:[NSString stringWithFormat:@"%d",CustomMessgeTypeRTCCall] forKey:@"type"];
    [mOptions setObject:[NSString stringWithFormat:@"%f",timestamp] forKey:@"timestamp"];

    //    NSDictionary *dataDict = @{
    //        @"type":[NSString stringWithFormat:@"%d",CustomMessgeTypeRTCCall],
    //        @"timestamp":[NSString stringWithFormat:@"%f",timestamp],
    //        @"sessionId":sessionId,
    //        @"sessionType":[NSString stringWithFormat:@"%zd",sessionType],
    //        @"data":@{
    //                @"channelName":channelName,
    //                @"callType":[NSString stringWithFormat:@"%ld",callType],
    //                @"msg":msg
    //        }
    //    };

    NSString *content = [NIMMessageMaker jsonStringWithDictionary:mOptions];
    NIMCustomSystemNotification *notifi = [[NIMCustomSystemNotification alloc]initWithContent:content];
    notifi.sendToOnlineUsersOnly = NO;

    NSString *apns = [options jsonString:@"apns"];
    if (apns.length) {

        //        notifi.sendToOnlineUsersOnly = NO;
        NIMCustomSystemNotificationSetting *setting = [[NIMCustomSystemNotificationSetting alloc]init];
        setting.shouldBeCounted = YES;
        setting.apnsEnabled = YES;
        setting.apnsWithPrefix = YES;

        notifi.apnsContent = apns;

        NSString *apns_sound = [options jsonString:@"apns_sound"];
        notifi.apnsPayload = [NIMMessageMaker makeApnsPayload:APNsTypeRTCMsg payloadData:mOptions sound:apns_sound];
        notifi.setting = setting;
    }

    //    NSLog(@"mOptions:%@ apns %@,options %@,notifi %@",mOptions,apns,options,notifi);

    [[NIMSDK sharedSDK].systemNotificationManager sendCustomNotification:notifi toSession:session completion:nil];//发送自定义通知
}

//-(void)sendRTCCallNotice2:(NSString *)sessionId sessionType:(NSInteger )sessionType channelName:(NSString *)channelName callType:(NSInteger )callType msg:(NSString *)msg apns:(BOOL)apns{
//    NIMSession *session = [NIMSession session:sessionId type:sessionType];
//
//    NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];
//    NSDictionary *dataDict = @{
//        @"type":[NSString stringWithFormat:@"%d",CustomMessgeTypeRTCCall],
//        @"timestamp":[NSString stringWithFormat:@"%f",timestamp],
//        @"sessionId":sessionId,
//        @"sessionType":[NSString stringWithFormat:@"%zd",sessionType],
//        @"data":@{
//                @"channelName":channelName,
//                @"callType":[NSString stringWithFormat:@"%zd",callType],
//                @"msg":msg
//        }
//    };
//
//    NSString *content = [self jsonStringWithDictionary:dataDict];
//    NIMCustomSystemNotification *notifi = [[NIMCustomSystemNotification alloc]initWithContent:content];
//
//    //    notifi.sendToOnlineUsersOnly = NO;
//    if (apns) {
//        //        notifi.sendToOnlineUsersOnly = NO;
//        NIMCustomSystemNotificationSetting *setting = [[NIMCustomSystemNotificationSetting alloc]init];
//        setting.shouldBeCounted = YES;
//        setting.apnsEnabled = apns;
//
//        notifi.apnsPayload = dataDict;
//        notifi.setting = setting;
//    }
//
//
//    [[NIMSDK sharedSDK].systemNotificationManager sendCustomNotification:notifi toSession:session completion:nil];//发送自定义通知
//}

//发送红包消息
- (void)sendRedPacketMessage:(NSString *)type comments:(NSString *)comments serialNo:(NSString *)serialNo{
    NSDictionary *dict = @{@"type":type,@"comments":comments,@"serialNo":serialNo};
    [self sendCustomMessage:CustomMessgeTypeRedpacket data:dict apns:@""];
}
//发送转账消息
- (void)sendBankTransferMessage:(NSString *)amount comments:(NSString *)comments serialNo:(NSString *)serialNo{
    NSDictionary *dict = @{@"amount":amount,@"comments":comments,@"serialNo":serialNo};
    [self sendCustomMessage:CustomMessgeTypeBankTransfer data:dict apns:@""];
}

//发送拆红包消息
-(void)sendRedPacketOpenMessage:(NSString *)sendId hasRedPacket:(NSString *)hasRedPacket serialNo:(NSString *)serialNo{
    NSString *strMyId = [NIMSDK sharedSDK].loginManager.currentAccount;
    NSDictionary *dict = @{@"sendId":sendId,@"openId":strMyId,@"hasRedPacket":hasRedPacket,@"serialNo":serialNo};
    NIMMessage *message;
    DWCustomAttachment *obj = [[DWCustomAttachment alloc]init];
    obj.custType = CustomMessgeTypeRedPacketOpenMessage;
    obj.dataDict = dict;
    message = [NIMMessageMaker msgWithCustomAttachment:obj andeSession:self._session apns:@""];
    NSTimeInterval timestamp = [[NSDate date] timeIntervalSince1970];
    message.timestamp = timestamp;
    if(![sendId isEqualToString:strMyId]){
        NSDictionary *dataDict = @{@"type":@"2",@"data":@{@"dict":dict,@"timestamp":[NSString stringWithFormat:@"%f",timestamp],@"sessionId":self._session.sessionId,@"sessionType":[NSString stringWithFormat:@"%zd",self._session.sessionType]}};
        
        NSString *content = [NIMMessageMaker jsonStringWithDictionary:dataDict];
        NIMSession *redSession = [NIMSession session:sendId type:NIMSessionTypeP2P];
        NIMCustomSystemNotification *notifi = [[NIMCustomSystemNotification alloc]initWithContent:content];
        notifi.sendToOnlineUsersOnly = NO;
        NIMCustomSystemNotificationSetting *setting = [[NIMCustomSystemNotificationSetting alloc]init];
        setting.shouldBeCounted = NO;
        setting.apnsEnabled = NO;
        notifi.setting = setting;
        notifi.apnsPayload = dataDict;
        [[NIMSDK sharedSDK].systemNotificationManager sendCustomNotification:notifi toSession:redSession completion:nil];//发送自定义通知
    }
    [[NIMSDK sharedSDK].conversationManager saveMessage:message forSession:self._session completion:nil];
    
}


-(void)sendCustomMessage:(NSDictionary *)options{
    NSString *sessionId = [options objectForKey:@"sessionId"];
    NSInteger sessionType = [options jsonInteger:@"sessionType"];
    NSInteger msgType = [options jsonInteger:@"msgType"];
    NSDictionary *data = [options jsonDict:@"data"];
    NSString *apns = [options objectForKey:@"apns"];
    //    NSString *apns_data = [options objectForKey:@"apns_data"];
    
    NIMSession *session = [NIMSession session:sessionId type:sessionType];
    [self sendCustomMessage:msgType data:data toSession:session apns:apns];
    
}


-(void)sendCardMessage:(NSDictionary *)options{
    NSString *sessionId = [options objectForKey:@"sessionId"];
    NSInteger sessionType = [options jsonInteger:@"sessionType"];
    NSDictionary *data = [options jsonDict:@"data"];
    NSString *apns = [options objectForKey:@"apns"];
    
    NIMSession *session = [NIMSession session:sessionId type:sessionType];
    [self sendCustomMessage:CustomMessgeTypeBusinessCard data:data toSession:session apns:apns];
    
}


//发送名片
- (void)sendCardMessage:(int)type sessionId:(NSString *)sessionId name:(NSString *)name imgPath:(NSString *)strImgPath{
    if (type == 0) {
        NIMUser *user = [[NIMSDK sharedSDK].userManager userInfo:sessionId];
        NIMUserInfo *userInfo = user.userInfo;
        name = userInfo.nickName ? userInfo.nickName : name;
        
    }else{
        NIMTeam *team = [[[NIMSDK sharedSDK] teamManager]teamById:sessionId];
        name = team.teamName ? team.teamName : name;
    }
    NSDictionary *dict = @{@"type":[NSNumber numberWithInt:(int)type],@"name":name,@"imgPath":strImgPath,@"sessionId":sessionId};
    [self sendCustomMessage:CustomMessgeTypeBusinessCard data:dict apns:@""];
}

//// dict字典转json字符串
//+ (NSString *)jsonStringWithDictionary:(NSDictionary *)dict
//{
//    if (dict && 0 != dict.count)
//    {
//        NSError *error = nil;
//        // NSJSONWritingOptions 是"NSJSONWritingPrettyPrinted"的话有换位符\n；是"0"的话没有换位符\n。
//        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
//        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
//        return jsonString;
//    }
//
//    return nil;
//}


//设置好友消息提醒
-(void)muteMessage:(NSString *)contactId mute:(NSString *)mute Succ:(Success)succ Err:(Errors)err{
    BOOL on;
    if ([mute isEqualToString:@"1"]) {
        on = true;
    }else{
        on = false;
    }
    [[NIMSDK sharedSDK].userManager updateNotifyState:on forUser:contactId completion:^(NSError *error) {
        if (!error) {
            succ(@"200");
        }else{
            err(@"操作失败");
        }
    }];
}

#pragma mark - NIMChatManagerDelegate

- (void)willSendMessage:(NIMMessage *)message
{
    [self refrashMessage:message From:@"send"];
    NIMModel *model = [NIMModel initShareMD];
    model.startSend = @{@"start":@"true"};
}
//发送结果
- (void)sendMessage:(NIMMessage *)message didCompleteWithError:(NSError *)error
{
    if (!error) {
        [self refrashMessage:message From:@"send"];
        [[NSUserDefaults standardUserDefaults]setObject: [NSString stringWithFormat:@"%f", message.timestamp] forKey:@"timestamp"];
    }else{
        NSDictionary *userInfo = error.userInfo;
        NSString *strEnum = [userInfo objectForKey:@"enum"];
        if ([strEnum isEqualToString:@"NIMRemoteErrorCodeInBlackList"]) {
            
            //X
            //NSString * tip = @"消息已发出，但被对方拒收了";
            NSString * tip = @"msg_send_reject";
            NIMMessage *tipMessage = [self msgWithTip:tip];
            tipMessage.timestamp = message.timestamp;
            [[NIMSDK sharedSDK].conversationManager saveMessage:tipMessage forSession:self._session completion:nil];
        }
        message.localExt = @{@"isFriend":@"NO"};
        [[NIMSDK sharedSDK].conversationManager updateMessage:message forSession:self._session completion:nil];
        [self refrashMessage:message From:@"send"];
    }
    NIMModel *model = [NIMModel initShareMD];
    if ([[NSString stringWithFormat:@"%@", error] isEqualToString:@"(null)"]) {
        model.endSend = @{@"end":@"true",@"error":@""};
    }else{
        model.endSend = @{@"end":@"true",@"error":[NSString stringWithFormat:@"%@", error]};
    }
}

//发送进度
-(void)sendMessage:(NIMMessage *)message progress:(float)progress
{
    [self refrashMessage:message From:@"send" ];
    NIMModel *model = [NIMModel initShareMD];
    model.endSend = @{@"progress":[NSString stringWithFormat:@"%f",progress]};
}


//接收消息
- (void)onRecvMessages:(NSArray *)messages
{
    NIMMessage *message = messages.firstObject;
    [self refrashMessage:message From:@"receive" ];
    
    if ([message.session.sessionId isEqualToString:_sessionID]) {
        //        [self refrashMessage:message From:@"receive" ];
        NIMMessageReceipt *receipt = [[NIMMessageReceipt alloc] initWithMessage:message];
        [[[NIMSDK sharedSDK] chatManager] sendMessageReceipt:receipt completion:nil];
        //标记已读消息
        [[NIMSDK sharedSDK].conversationManager markAllMessagesReadInSession:self._session];
        
        if (![message.from isEqualToString:[NIMSDK sharedSDK].loginManager.currentAccount]) {
            [self playTipsMusicWithMessage:message];
        }
    }
}

- (void)playTipsMusicWithMessage:(NIMMessage *)message{
    BOOL needToPlay = NO;
    if (message.messageType == 100) {
        NIMCustomObject *customObject = message.messageObject;
        DWCustomAttachment *obj = customObject.attachment;
        if (obj.custType == CustomMessgeTypeRedPacketOpenMessage){
            return;
        }else if(obj.custType == CustomMessgeTypeRedpacket){//红包消息
            [self.player stop];
            [self.redPacketPlayer stop];
            [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryAmbient error:nil];
            [self.redPacketPlayer play];
            return;
        }
    }
    if (message.messageType == NIMMessageTypeNotification) return;
    if (message.session.sessionType == NIMSessionTypeP2P) {//个人
        NIMUser *user = [[NIMSDK sharedSDK].userManager userInfo:message.session.sessionId];
        needToPlay = user.notifyForNewMsg;
        
    }else if(message.session.sessionType == NIMSessionTypeTeam){//群
        
        NIMTeam *team = [[[NIMSDK sharedSDK] teamManager]teamById:message.session.sessionId];
        needToPlay = team.notifyStateForNewMsg == NIMTeamNotifyStateAll ? YES : NO;
    }
    if (needToPlay) {
        [self.player stop];
        [self.redPacketPlayer stop];
        [[AVAudioSession sharedInstance] setCategory: AVAudioSessionCategoryAmbient error:nil];
        [self.player play];
    }
}

- (void)fetchMessageAttachment:(NIMMessage *)message progress:(float)progress
{
    NSLog(@"下载图片");
    //    if ([message.session isEqual:self._session]) {
    //        [self.interactor updateMessage:message];
    //    }
}

- (void)fetchMessageAttachment:(NIMMessage *)message didCompleteWithError:(NSError *)error
{
    NSLog(@"完成下载图片");
    [[NSNotificationCenter defaultCenter]postNotificationName:@"RNNeteaseimDidCompletePic" object:nil];
    //    if ([message.session isEqual:self._session]) {
    //        NIMMessageModel *model = [self.interactor findMessageModel:message];
    //        //下完缩略图之后，因为比例有变化，重新刷下宽高。
    //        [model calculateContent:self.tableView.frame.size.width force:YES];
    //        [self.interactor updateMessage:message];
    //    }
}

- (void)onRecvMessageReceipt:(NIMMessageReceipt *)receipt
{
    NIMModel *mode = [NIMModel initShareMD];
    mode.receipt = @"1";
}

//写到RNNotificationCenter去了
//- (void)onRecvRevokeMessageNotification:(NIMRevokeMessageNotification *)notification
//{
//    NSString * tip = [self tipOnMessageRevoked:notification];
//    NIMMessage *tipMessage = [self msgWithTip:tip];
//    tipMessage.timestamp = notification.timestamp;
//    NIMMessage *deleMess = notification.message;
//    NSDictionary *deleteDict = @{@"msgId":deleMess.messageId};
//
//    // saveMessage 方法执行成功后会触发 onRecvMessages: 回调，但是这个回调上来的 NIMMessage 时间为服务器时间，和界面上的时间有一定出入，所以要提前先在界面上插入一个和被删消息的界面时间相符的 Tip, 当触发 onRecvMessages: 回调时，组件判断这条消息已经被插入过了，就会忽略掉。
//    [[NIMSDK sharedSDK].conversationManager saveMessage:tipMessage
//                                             forSession:notification.session
//                                             completion:^(NSError * _Nullable error) {
//                                                  [NIMModel initShareMD].deleteMessDict = deleteDict;
//                                             }];
//}

#pragma mark - NIMMediaManagerDelegate
- (void)recordAudio:(NSString *)filePath didBeganWithError:(NSError *)error {
    if (!filePath || error) {
        [self onRecordFailed:error];
    }
}

- (void)recordAudio:(NSString *)filePath didCompletedWithError:(NSError *)error {
    if(!error) {
        if ([self recordFileCanBeSend:filePath]) {
            [[[NIMSDK sharedSDK] chatManager] sendMessage:[NIMMessageMaker msgWithAudio:filePath andeSession:self._session apns:@""] toSession:self._session error:nil];
        }else{
            [self showRecordFileNotSendReason];
        }
    } else {
        NSLog(@"^^^^%@",error);
    }
}

- (void)recordAudioDidCancelled {
    
}
//监听录音状态
- (void)recordAudioProgress:(NSTimeInterval)currentTime{
    NIMModel *model = [NIMModel initShareMD];
    NSDictionary *Audic = @{@"currentTime":[NSString stringWithFormat:@"%f",currentTime],@"recordPower":[NSString stringWithFormat:@"%f",[[NIMSDK sharedSDK].mediaManager recordPeakPower]]};
    model.audioDic = Audic;
}

//播放结束回调
- (void)playAudio:(NSString *)filePath didCompletedWithError:(nullable NSError *)error{
    if(!error) {
        NIMModel *model = [NIMModel initShareMD];
        NSDictionary *Audic = @{@"playEnd":@"true"};
        model.audioDic = Audic;
    } else {
        NSLog(@"%@",error);
    }
}

- (void)recordAudioInterruptionBegin {
    [[NIMSDK sharedSDK].mediaManager cancelRecord];
}
#pragma mark - 录音相关接口
- (void)onRecordFailed:(NSError *)error{}

- (BOOL)recordFileCanBeSend:(NSString *)filepath
{
    return YES;
}

- (void)showRecordFileNotSendReason{}


#pragma mark - NIMConversationManagerDelegate
- (void)messagesDeletedInSession:(NIMSession *)session{
    //    [self.interactor resetMessages];
    //    [self.tableView reloadData];
}

- (void)didAddRecentSession:(NIMRecentSession *)recentSession
           totalUnreadCount:(NSInteger)totalUnreadCount{
    [self changeUnreadCount:recentSession totalUnreadCount:totalUnreadCount];
}

- (void)didUpdateRecentSession:(NIMRecentSession *)recentSession
              totalUnreadCount:(NSInteger)totalUnreadCount{
    [self changeUnreadCount:recentSession totalUnreadCount:totalUnreadCount];
}

- (void)didRemoveRecentSession:(NIMRecentSession *)recentSession
              totalUnreadCount:(NSInteger)totalUnreadCount{
    [self changeUnreadCount:recentSession totalUnreadCount:totalUnreadCount];
}


- (void)changeUnreadCount:(NIMRecentSession *)recentSession
         totalUnreadCount:(NSInteger)totalUnreadCount{
    
    //    if ([recentSession.session isEqual:self.session]) {
    //        return;
    //    }
    //    [self changeLeftBarBadge:totalUnreadCount];
}

//XX
- (void)startChatMsg
{
    [[NIMSDK sharedSDK].chatManager addDelegate:self];
    //    [[NIMSDK sharedSDK].conversationManager addDelegate:self];
    [[NIMSDK sharedSDK].systemNotificationManager addDelegate:self];
}


//XX
- (void)stopChatMsg
{
    [[NIMSDK sharedSDK].chatManager removeDelegate:self];
    [[NIMSDK sharedSDK].systemNotificationManager removeDelegate:self];
}


- (void)addListener
{
    //    [[NIMSDK sharedSDK].chatManager addDelegate:self];
    [[NIMSDK sharedSDK].conversationManager addDelegate:self];
    //    [[NIMSDK sharedSDK].systemNotificationManager addDelegate:self];
}


#pragma mark - NIMSystemNotificationManagerDelegate
- (void)onReceiveCustomSystemNotification:(NIMCustomSystemNotification *)notification
{
   
    
    //
    //    if (!notification.sendToOnlineUsersOnly) {
    //        return;
    //    }
    
    NSLog(@"onReceiveCustomSystemNotification apnsPayload:%@,content:%@",notification.apnsPayload,notification.content);
    
//    NSData *data = [[notification content] dataUsingEncoding:NSUTF8StringEncoding];
     
    NSDictionary *apnsPayload = notification.apnsPayload;
    if (apnsPayload) {
        
        
        
//        NSMutableDictionary *dict = [NSJSONSerialization JSONObjectWithData:data     options:NSJSONReadingMutableContainers      error:nil];
        
        NSMutableDictionary *notice = [[NSMutableDictionary alloc] initWithDictionary:apnsPayload copyItems:YES];
        NSLog(@"onReceiveCustomSystemNotification notice:%@ payload：%@",notice,[notice objectForKey:@"payload"]);
        
        if([notice objectForKey:@"payload"] == nil){
            return;
        }
        
        
        NSData *payloadData = [[notice objectForKey:@"payload"] dataUsingEncoding:NSUTF8StringEncoding];
        
        [notice setObject:[NSJSONSerialization JSONObjectWithData:payloadData     options:NSJSONReadingMutableContainers      error:nil]  forKey:@"payload"];
        
        NSLog(@"onReceiveCustomSystemNotification notice:%@",notice);
//        [notice setObject:[apnsPayload objectForKey:@"payload"] forKey:@"payload"];
        
        [notice setObject:[NSString stringWithFormat:@"%lf",notification.timestamp] forKey:@"timestamp"];
        [notice setObject:[NSString stringWithFormat:@"%lld",notification.notificationId] forKey:@"notificationId"];
        
        
//        NSLog(@"onReceiveCustomSystemNotification: sessionType %zd",[dict jsonInteger:@"sessionType"]);
//        NSLog(@"onReceiveCustomSystemNotification:%@,dict:%@",notification,dict);
//
        NIMKitInfo *sourceMember;
        
        if([notification receiverType] == NIMSessionTypeP2P){
            sourceMember = [[NIMKit sharedKit] infoByUser:notification.sender option:nil];
        }
        else{
            sourceMember = [[NIMKit sharedKit] infoByTeam:notification.sender option:nil];
        }
        
        if (sourceMember!=nil) {
            NSString *avatar = sourceMember.avatarUrlString!=nil && sourceMember.avatarUrlString.length>0?sourceMember.avatarUrlString:@"";
            [notice setObject:@{
                @"receiver":@"receiver",
                @"receiverType":[NSString stringWithFormat:@"%zd",notification.receiverType],
                @"name":[sourceMember showName],
                @"avatar":avatar,
                @"contactId":sourceMember.infoId
            } forKey:@"sender"];
        }
        else{
//            [notice setObject:notification.sender forKey:@"sender_id"];
            [notice setObject:@{
                @"receiver":@"receiver",
                @"receiverType":[NSString stringWithFormat:@"%zd",notification.receiverType],
                @"name":@"",
                @"avatar":@"",
                @"contactId":notification.sender
            } forKey:@"sender"];
        }
        
//        NSLog(@"dict:%@",notice);
        
        NIMModel *model = [NIMModel initShareMD];
        model.customNotify = notice;
        
        
        
        
        //        if ([dict jsonInteger:NTESNotifyID] == NTESCommandTyping &&self._session.sessionType == NIMSessionTypeP2P && [notification.sender isEqualToString:self._session.sessionId])
        //        {
        //            NSLog(@"正在输入...");
        //        }
    }
}


-(void)refrashMessage:(NIMMessage *)message From:(NSString *)from {
    NSMutableArray *messageArr = [NSMutableArray array];
    NSMutableDictionary *dic2 = [NSMutableDictionary dictionary];
    NIMUser   *user = [[NIMSDK sharedSDK].userManager userInfo:message.from];
    NSMutableDictionary *fromUser = [NSMutableDictionary dictionary];
    [fromUser setObject:[NSString stringWithFormat:@"%@",user.userInfo.avatarUrl] forKey:@"avatar"];
    NSString *strAlias = user.alias;
    if (strAlias.length) {
        [fromUser setObject:strAlias forKey:@"name"];
    }else if(user.userInfo.nickName.length){
        [fromUser setObject:[NSString stringWithFormat:@"%@",user.userInfo.nickName] forKey:@"name"];
    }else{
        [fromUser setObject:[NSString stringWithFormat:@"%@",user.userId] forKey:@"name"];
    }
    [fromUser setObject:[NSString stringWithFormat:@"%@", message.from] forKey:@"_id"];
    [fromUser setObject:[NSString stringWithFormat:@"%@", message.from] forKey:@"id"];
    
    NSArray *key = [fromUser allKeys];
    for (NSString *tem  in key) {
        if ([[fromUser objectForKey:tem] isEqualToString:@"(null)"]) {
            [fromUser setObject:@"" forKey:tem];
        }
    }
    [dic2 setObject:[NSString stringWithFormat:@"%@", message.text] forKey:@"text"];
    [dic2 setObject:[NSString stringWithFormat:@"%@", message.session.sessionId] forKey:@"sessionId"];
    [dic2 setObject:[NSString stringWithFormat:@"%ld", message.session.sessionType] forKey:@"sessionType"];
    switch (message.deliveryState) {
        case NIMMessageDeliveryStateFailed:
            [dic2 setObject:@"send_failed" forKey:@"status"];
            break;
        case NIMMessageDeliveryStateDelivering:
            [dic2 setObject:@"send_going" forKey:@"status"];
            break;
        case NIMMessageDeliveryStateDeliveried:
            [dic2 setObject:@"send_succeed" forKey:@"status"];
            break;
        default:
            [dic2 setObject:@"send_failed" forKey:@"status"];
            break;
    }
    NSString *isFriend = [message.localExt objectForKey:@"isFriend"];
    if ([isFriend length]) {
        if ([isFriend isEqualToString:@"NO"]) {
            [dic2 setObject:@"send_failed" forKey:@"status"];
        }
    }
    [dic2 setObject: [NSNumber numberWithBool:message.isOutgoingMsg] forKey:@"isOutgoing"];
    [dic2 setObject:[NSString stringWithFormat:@"%f", message.timestamp] forKey:@"timeString"];
    //    [dic2 setObject:[NSNumber numberWithBool:NO] forKey:@"isShowTime"];
    [dic2 setObject:[NSString stringWithFormat:@"%@", message.messageId] forKey:@"msgId"];
    [dic2 setObject:fromUser forKey:@"fromUser"];
    if (message.messageType == NIMMessageTypeText) {
        [dic2 setObject:@"text" forKey:@"msgType"];
    }else if (message.messageType  == NIMMessageTypeImage) {
        [dic2 setObject:@"image" forKey:@"msgType"];
        NIMImageObject *object = message.messageObject;
        [dic2 setObject:[NSString stringWithFormat:@"%@", [object thumbPath]] forKey:@"mediaPath"];
        NSMutableDictionary *imgObj = [NSMutableDictionary dictionary];
        [imgObj setObject:[NSString stringWithFormat:@"%@", [object thumbPath] ] forKey:@"thumbPath"];
        [imgObj setObject:[NSString stringWithFormat:@"%@", [object thumbUrl] ] forKey:@"thumbUrl"];
        [imgObj setObject:[NSString stringWithFormat:@"%@",[object url] ] forKey:@"url"];
        [imgObj setObject:[NSString stringWithFormat:@"%@",[object displayName] ] forKey:@"displayName"];
        [imgObj setObject:[NSString stringWithFormat:@"%f",[object size].height] forKey:@"imageHeight"];
        [imgObj setObject:[NSString stringWithFormat:@"%f",[object size].width] forKey:@"imageWidth"];
        [imgObj setObject:[NSString stringWithFormat:@"%lld",[object fileLength] ] forKey:@"size"];
        [dic2 setObject:imgObj forKey:@"extend"];
    }else if(message.messageType == NIMMessageTypeAudio){
        [dic2 setObject:@"voice" forKey:@"msgType"];
        NIMAudioObject *object = message.messageObject;
        if ([[NSFileManager defaultManager] fileExistsAtPath:object.path]) {
            [dic2 setObject:[NSString stringWithFormat:@"%@",object.path] forKey:@"mediaPath"];
        }
        
        //        [dic2 setObject:[NSString stringWithFormat:@"%@",object.path] forKey:@"mediaPath"];
        [dic2 setObject:[NSString stringWithFormat:@"%@",object.url] forKey:@"url"];
        [dic2 setObject:[NSNumber numberWithInteger:object.duration] forKey:@"duration"];
        NSMutableDictionary *voiceObj = [NSMutableDictionary dictionary];
        [voiceObj setObject:[NSString stringWithFormat:@"%@", [object url]] forKey:@"url"];
        [voiceObj setObject:[NSString stringWithFormat:@"%zd",(object.duration/1000)] forKey:@"duration"];
        [voiceObj setObject:[NSNumber  numberWithBool:message.isPlayed] forKey:@"isPlayed"];
        [dic2 setObject:voiceObj forKey:@"extend"];
    }else  if(message.messageType == NIMMessageTypeVideo ){
        [dic2 setObject:@"video" forKey:@"msgType"];
        NIMVideoObject *object = message.messageObject;
        
        [dic2 setObject:[NSString stringWithFormat:@"%@",object.url ] forKey:@"videoUrl"];
        [dic2 setObject:[NSString stringWithFormat:@"%@", object.displayName ] forKey:@"displayName"];
        [dic2 setObject:[NSString stringWithFormat:@"%@", object.coverUrl ] forKey:@"coverUrl"];
        [dic2 setObject:[NSString stringWithFormat:@"%f",object.coverSize.height ] forKey:@"coverSizeHeight"];
        [dic2 setObject:[NSString stringWithFormat:@"%f", object.coverSize.width ] forKey:@"coverSizeWidth"];
        [dic2 setObject:[NSString stringWithFormat:@"%ld",object.duration ] forKey:@"duration"];
        [dic2 setObject:[NSString stringWithFormat:@"%lld",object.fileLength] forKey:@"fileLength"];
        
        NSMutableDictionary *videoObj = [NSMutableDictionary dictionary];
        [videoObj setObject:[NSString stringWithFormat:@"%@", object.displayName ] forKey:@"displayName"];
        [videoObj setObject:[NSString stringWithFormat:@"%ld",object.duration ] forKey:@"duration"];
        [videoObj setObject:[NSString stringWithFormat:@"%lld",object.fileLength] forKey:@"fileLength"];
        [videoObj setObject:[NSString stringWithFormat:@"%@",object.url ] forKey:@"videoUrl"];
        [videoObj setObject:[NSString stringWithFormat:@"%@", object.coverUrl ] forKey:@"coverUrl"];
        [dic2 setObject:videoObj forKey:@"extend"];
        /*
         if([[NSFileManager defaultManager] fileExistsAtPath:object.coverPath]){
         [dic2 setObject:[NSString stringWithFormat:@"%@",object.coverPath] forKey:@"coverPath"];
         }else{
         //如果封面图下跪了，点进视频的时候再去下一把封面图
         [[NIMSDK sharedSDK].resourceManager download:object.coverUrl filepath:object.coverPath progress:nil completion:^(NSError *error) {
         if (!error) {
         [dic2 setObject:[NSString stringWithFormat:@"%@",object.coverPath] forKey:@"coverPath"];
         }
         }];
         }*/
        if ([[NSFileManager defaultManager] fileExistsAtPath:object.path]) {
            [dic2 setObject:[NSString stringWithFormat:@"%@",object.path] forKey:@"mediaPath"];
        }else{
            
            [[NIMObject initNIMObject] downLoadVideo:object Error:^(NSError *error) {
                if (!error) {
                    [dic2 setObject:[NSString stringWithFormat:@"%@",object.path] forKey:@"mediaPath"];
                    NSLog(@"--------下载完成~！！！dic2:%@",dic2);
                    NIMModel *model = [NIMModel initShareMD];
                    model.videoProgress = [NSMutableArray arrayWithObjects:dic2, nil];
                }
            } progress:^(float progress) {
                NSLog(@"----------下载进度%f   dic2:%@",progress,dic2);
            }];
        }
    }else if(message.messageType == NIMMessageTypeLocation){
        [dic2 setObject:@"location" forKey:@"msgType"];
        NIMLocationObject *object = message.messageObject;
        NSMutableDictionary *locationObj = [NSMutableDictionary dictionary];
        [locationObj setObject:[NSString stringWithFormat:@"%f", object.latitude ] forKey:@"latitude"];
        [locationObj setObject:[NSString stringWithFormat:@"%f", object.longitude ] forKey:@"longitude"];
        [locationObj setObject:[NSString stringWithFormat:@"%@", object.title ] forKey:@"title"];
        [dic2 setObject:locationObj forKey:@"extend"];
        
    }else if(message.messageType == NIMMessageTypeTip){//提醒类消息
        [dic2 setObject:@"notification" forKey:@"msgType"];
        //        NSMutableDictionary *notiObj = [NSMutableDictionary dictionary];
        //        [notiObj setObject:message.text forKey:@"tipMsg"];
        //        [notiObj setObject:@{@"local":message.localExt,@"remote":message.remoteExt} forKey:@"options"];
        //
        //        NSMutableDictionary *options = [NSMutableDictionary dictionary];
        //        [options setObject:message.localExt!=nil?message.localExt:@"" forKey:@"local"];
        //        [options setObject:message.remoteExt!=nil?message.remoteExt:@"" forKey:@"remote"];
        //        [notiObj setObject:options forKey:@"options"];
        
        NSDictionary *notiObj = [ConversationViewController getTipMessageExtend:message];
        [dic2 setObject:notiObj forKey:@"extend"];
    }else if (message.messageType == NIMMessageTypeNotification) {
        [dic2 setObject:@"notification" forKey:@"msgType"];
        NSMutableDictionary *notiObj = [NSMutableDictionary dictionary];
        NIMNotificationObject *object = message.messageObject;
        switch (object.notificationType) {
            case NIMNotificationTypeTeam:
            case NIMNotificationTypeChatroom:
            {
                //X
                //[notiObj setObject:[NIMKitUtil messageTipContent:message] forKey:@"tipMsg"];
                
                NSMutableDictionary *options = [NSMutableDictionary dictionary];
                [notiObj setObject:[NIMKitUtil messageTipContent2:message result:options] forKey:@"tipMsg"];
                [notiObj setObject:options forKey:@"options"];
                break;
            }
            case NIMNotificationTypeNetCall:{
                [notiObj setObject:[NIMKitUtil messageTipContent:message]forKey:@"tipMsg"];
                
                
                break;
            }
            default:
                break;
        }
        [dic2 setObject:notiObj forKey:@"extend"];
        
    }else if (message.messageType == NIMMessageTypeCustom) {
        NIMCustomObject *customObject = message.messageObject;
        DWCustomAttachment *obj = customObject.attachment;
        
        if (obj) {
            NSLog(@"NIMMessageTypeCustom：custType %ld dataDict:%@",obj.custType,obj.dataDict);
            //            [dic2 setObject:[NSNumber numberWithInteger:obj.custType] forKey:@"custType"];
            [dic2 setObject:obj.custTypeStr forKey:@"custType"];
            switch (obj.custType) {
                case CustomMessgeTypeRTCCall: //rtc_call
                {
                    [dic2 setObject:obj.dataDict forKey:@"extend"];
                    [dic2 setObject:@"rtcCall" forKey:@"msgType"];
                }
                    break;
                case CustomMessgeTypeRedpacket: //红包
                {
                    [dic2 setObject:obj.dataDict forKey:@"extend"];
                    [dic2 setObject:@"redpacket" forKey:@"msgType"];
                }
                    break;
                case CustomMessgeTypeBankTransfer: //转账
                {
                    [dic2 setObject:obj.dataDict  forKey:@"extend"];
                    [dic2 setObject:@"transfer" forKey:@"msgType"];
                }
                    break;
                case CustomMessgeTypeRedPacketOpenMessage: //拆红包消息
                {
                    NSDictionary *dataDict = [self dealWithData:obj.dataDict];
                    if (dataDict) {
                        [dic2 setObject:dataDict  forKey:@"extend"];
                        [dic2 setObject:@"redpacketOpen" forKey:@"msgType"];
                    }else{
                        return;
                    }
                }
                    break;
                    
                case CustomMessgeTypeAccountNotice: //账户通知，与账户金额相关变动
                case CustomMessgeTypeUrl: //链接
                {
                    [dic2 setObject:[NSString stringWithFormat:@"%d",message.isRemoteRead] forKey:@"isRemoteRead"];
                    //                    [dic2 setObject:[NSString stringWithFormat:@"%ld", message.messageType] forKey:@"msgType"];
                    if (obj.custType == CustomMessgeTypeAccountNotice) {
                        [dic2 setObject:obj.dataDict  forKey:@"extend"];
                        [dic2 setObject:@"account_notice" forKey:@"msgType"];
                    }else{
                        [dic2 setObject:obj.dataDict  forKey:@"extend"];
                        [dic2 setObject:@"url" forKey:@"msgType"];
                    }
                }
                    break;
                case CustomMessgeTypeBusinessCard://名片
                {
                    [dic2 setObject:obj.dataDict  forKey:@"extend"];
                    [dic2 setObject:@"card" forKey:@"msgType"];
                }
                    break;
                case CustomMessgeTypeCustom://自定义
                {
                    [dic2 setObject:obj.dataDict  forKey:@"extend"];
                    [dic2 setObject:@"custom" forKey:@"msgType"];
                }
                    break;
                default:
                {
                    [dic2 setObject:obj.dataDict  forKey:@"extend"];
                    [dic2 setObject:@"unknown" forKey:@"msgType"];
                }
                    break;
            }
        }
    }else{
        [dic2 setObject:@"unknown" forKey:@"msgType"];
        NSMutableDictionary *unknowObj = [NSMutableDictionary dictionary];
        [dic2 setObject:unknowObj  forKey:@"extend"];
    }
    [messageArr addObject:dic2];
    //接收消息
    NIMModel *model = [NIMModel initShareMD];
    if ([from isEqualToString:@"receive"]) {
        model.ResorcesArr = messageArr;
    }else if ([from isEqualToString:@"send"]){
        //发送消息
        model.sendState = messageArr;
    }
}
//处理拆红包消息
- (NSDictionary *)dealWithData:(NSDictionary *)dict{
    NSString *strOpenId = [self stringFromKey:@"openId" andDict:dict];
    NSString *strSendId = [self stringFromKey:@"sendId" andDict:dict];
    NSString *strNo = [self stringFromKey:@"serialNo" andDict:dict];
    NSString *strMyId = [NIMSDK sharedSDK].loginManager.currentAccount;
    NSString *strContent;
    NSString *lastString = @"";
    NSInteger hasRedPacket = [[dict objectForKey:@"hasRedPacket"] integerValue];
    if (hasRedPacket == 1) {//红包已领完
        lastString = @"，你的红包已被领完";
    }
    if ([strOpenId isEqualToString:strMyId]&&[strSendId isEqualToString:strMyId]) {
        strContent = [NSString stringWithFormat:@"你领取了自己发的红包%@",lastString ];
    }else if ([strOpenId isEqualToString:strMyId]){
        NSString *strSendName = [self getUserName:strSendId];
        strContent = [NSString stringWithFormat:@"你领取了%@的红包",strSendName];
    }else if([strSendId isEqualToString:strMyId]){
        NSString *strOpenName = [self getUserName:strOpenId];
        strContent = [NSString stringWithFormat:@"%@领取了你的红包%@",strOpenName,lastString];
    }else{//别人发的别人领的
        return nil;
    }
    NSDictionary *dataDict = @{@"tipMsg":strContent,@"serialNo":strNo};
    return dataDict;
}

- (NSString *)getUserName:(NSString *)userID{
    NSString *strTmpName = @"";
    NIMUser *user = [[NIMSDK sharedSDK].userManager userInfo:userID];
    strTmpName = user.alias;
    if (![strTmpName length]) {
        strTmpName = user.userInfo.nickName;
    }
    if (![strTmpName length]) {//从服务器获取
        [[ContactViewController initWithContactViewController]fetchUserInfos:userID Success:^(id param) {
            
        } error:^(NSString *error) {
            
        }];
        strTmpName = userID;
    }
    return strTmpName;
}


- (NSString *)stringFromKey:(NSString *)strKey andDict:(NSDictionary *)dict{
    NSString *text = [dict objectForKey:strKey];
    return text?text:@" ";
}

//转发消息
-(void)forwardMessage:(NSString *)messageId sessionId:(NSString *)sessionId sessionType:(NSString *)sessionType content:(NSString *)content success:(Success)succe{
    NIMSession *session = [NIMSession session:sessionId type:[sessionType integerValue]];
    NSArray *currentMessage = [[[NIMSDK sharedSDK] conversationManager] messagesInSession:self._session messageIds:@[messageId]];
    NIMMessage *message = currentMessage[0];
    [[NIMSDK sharedSDK].chatManager forwardMessage:message toSession:session error:nil];
    //发送消息
    NIMMessage *messages = [[NIMMessage alloc] init];
    messages.text    = content;
    [[NIMSDK sharedSDK].chatManager sendMessage:messages toSession:session error:nil];
    succe(@"已发送");
}
//撤回消息
-(void)revokeMessage:(NSString *)messageId success:(Success)succe{
    NSArray *currentMessage = [[[NIMSDK sharedSDK] conversationManager] messagesInSession:self._session messageIds:@[messageId]];
    NIMMessage *currentmessage = currentMessage[0];
    //    __weak typeof(self) weakSelf = self;
    [[NIMSDK sharedSDK].chatManager revokeMessage:currentmessage completion:^(NSError * _Nullable error) {
        if (error) {
            
            if (error.code == NIMRemoteErrorCodeDomainExpireOld) {
                succe(@"expired");
                //                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:@"发送时间超过2分钟的消息，不能被撤回" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
                //                [alert show];
            }else{
                succe(@"error");
                DDLogError(@"revoke message eror code %zd",error.code);
                NSLog(@"消息撤回失败，请重试");
            }
        }
        else
        {
            succe(@"succeed");
            NSMutableDictionary *options = [self tipOnMessageRevoked:currentmessage session:self._session isSelf:YES messageFromUserId:@""];
            NIMMessage *tipMessage = [self msgWithTip:[options objectForKey:@"tipMsg"]];
            [options setObject:messageId forKey:@"msgId"];
            
            tipMessage.localExt = options;
            tipMessage.timestamp = currentmessage.timestamp+1;
            
            NSDictionary *deleteDict = @{@"msgId":messageId};
            [NIMModel initShareMD].deleteMessDict = deleteDict;
            
            // saveMessage 方法执行成功后会触发 onRecvMessages: 回调，但是这个回调上来的 NIMMessage 时间为服务器时间，和界面上的时间有一定出入，所以要提前先在界面上插入一个和被删消息的界面时间相符的 Tip, 当触发 onRecvMessages: 回调时，组件判断这条消息已经被插入过了，就会忽略掉。
            [[NIMSDK sharedSDK].conversationManager saveMessage:tipMessage forSession:self._session completion:nil];
        }
    }];
    
}
//删除一条信息
-(void)deleteMsg:(NSString *)messageId{
    NSArray *currentMessage = [[[NIMSDK sharedSDK] conversationManager] messagesInSession:self._session messageIds:@[messageId]];
    NIMMessage *message = currentMessage[0];
    [[NIMSDK sharedSDK].conversationManager deleteMessage:message];
}
//清空聊天记录
-(void)clearMsg:(NSString *)contactId type:(NSString *)type{
    NIMSession  *session = [NIMSession session:contactId type:[type integerValue]];
    NIMDeleteMessagesOption *option = [[NIMDeleteMessagesOption alloc]init];
    option.removeSession = NO;
    [[NIMSDK sharedSDK].conversationManager deleteAllmessagesInSession:session option:option];
    //    [[NIMSDK sharedSDK].conversationManager deleteAllmessagesInSession:session removeRecentSession:NO];
}
- (NIMMessage *)msgWithTip:(NSString *)tip
{
    NIMMessage *message        = [[NIMMessage alloc] init];
    NIMTipObject *tipObject    = [[NIMTipObject alloc] init];
    message.messageObject      = tipObject;
    message.text               = tip;
    NIMMessageSetting *setting = [[NIMMessageSetting alloc] init];
    setting.apnsEnabled        = NO;
    setting.shouldBeCounted    = NO;
    message.setting            = setting;
    return message;
}

- (NSMutableDictionary *)tipOnMessageRevoked:(NIMMessage*)message session:(NIMSession*)session isSelf:(BOOL) isSelf messageFromUserId:(NSString *)messageFromUserId
{
    //    NSString *fromUid = nil;
    //    NIMSession *session = nil;
    NSMutableDictionary *options = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *format = [[NSMutableDictionary alloc] init];
    
    //    if ([message isKindOfClass:[NIMMessage class]])
    //    {
    //        fromUid = [(NIMMessage *)message from];
    //        session = [(NIMMessage *)message session];
    //    }
    //    else if([message isKindOfClass:[NIMRevokeMessageNotification class]])
    //    {
    //        fromUid = [(NIMRevokeMessageNotification *)message fromUserId];
    //        session = [(NIMRevokeMessageNotification *)message session];
    //    }
    //    else
    //    {
    //        assert(0);
    //    }
    
    
    NSString *tipMsg = @"notification_";
    [options setObject:@"notification" forKey:@"msgType"];
    [options setObject:@"revoke" forKey:@"tipType"];
    
    
    //    [options setObject:fromUid forKey:@"fromUid"];
    [options setObject:[NSString stringWithFormat:@"%zd",session.sessionType] forKey:@"sessionType"];
    [options setObject:session.sessionId forKey:@"sessionId"];
    
    //    BOOL isFromMe = [fromUid isEqualToString:[[NIMSDK sharedSDK].loginManager currentAccount]];
    
    
    switch (session.sessionType) {
        case NIMSessionTypeP2P:
            [options setObject:@"p2p" forKey:@"notificationType"];
            
            if (!isSelf) {
                NIMKitInfoFetchOption *option = [[NIMKitInfoFetchOption alloc] init];
                option.session = session;
                NIMKitInfo *info = [[NIMKit sharedKit] infoByUser:messageFromUserId option:option];
                //                 NSLog(@"info %@ %@",info.showName,tipMsg);
                [format setObject:info!=nil?info.showName:@"" forKey:@"source"];
                [options setObject:@"p2p_revoked" forKey:@"operationType"];
                tipMsg  = [NSString stringWithFormat:@"%@%@",tipMsg,@"p2p_revoked" ];
                
                
            }
            else{
                [options setObject:@"you_revoked" forKey:@"operationType"];
                tipMsg  = [NSString stringWithFormat:@"%@%@",tipMsg,@"you_revoked" ];
            }
            
            break;
        case NIMSessionTypeTeam:{
            [options setObject:@"team" forKey:@"notificationType"];
            
            if (!isSelf) {
                NIMKitInfoFetchOption *option = [[NIMKitInfoFetchOption alloc] init];
                option.session = session;
                NIMKitInfo *info = [[NIMKit sharedKit] infoByUser:message.from option:option];
                [options setObject:@"member_revoked" forKey:@"operationType"];
                //                [format setObject:info.showName forKey:@"source"];
                [format setObject:info!=nil?info.showName:@"" forKey:@"source"];
                //                [format setObject:fromName forKey:@"source"];
                tipMsg  = [NSString stringWithFormat:@"%@%@",tipMsg,@"member_revoked" ];
            }
            else{
                [options setObject:@"you_revoked" forKey:@"operationType"];
                tipMsg  = [NSString stringWithFormat:@"%@%@",tipMsg,@"you_revoked" ];
            }
            
        }
            break;
        default:
            break;
    }
    
    [options setObject:format forKey:@"format"];
    [options setObject:tipMsg forKey:@"tipMsg"];
    return options;
}
//麦克风权限
- (void)onTouchVoiceSucc:(Success)succ Err:(Errors)err{
    if ([[AVAudioSession sharedInstance] respondsToSelector:@selector(requestRecordPermission:)]) {
        [[AVAudioSession sharedInstance] performSelector:@selector(requestRecordPermission:) withObject:^(BOOL granted) {
            if (granted) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    succ(@"200");
                });
            }
            else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    err(@"没有麦克风权限");
                });
            }
        }];
    }
}


-(void)stopSession;
{
    
    _sessionID = nil;
    _type = nil;
    self._session = nil;
    
    [[NIMSDK sharedSDK].conversationManager removeDelegate:self];
    //    [[NIMSDK sharedSDK].chatManager removeDelegate:self];
    //    [[NIMSDK sharedSDK].systemNotificationManager removeDelegate:self];
}
//判断是不是好友
- (BOOL)isFriendToSendMessage:(NIMMessage *)message{
    return [self isFriendToSendMessage:message toSession:self._session];
}

//判断是不是好友
- (BOOL)isFriendToSendMessage:(NIMMessage *)message toSession:(NIMSession *)session{
    if (session.sessionType == NIMSessionTypeP2P) {//点对点
        NSString *strSessionId = session.sessionId;
        if ([[NIMSDK sharedSDK].userManager isMyFriend:strSessionId]) {//判断是否为自己好友
            return YES;
        }else{
            message.localExt = @{@"isFriend":@"NO"};
            [[NIMSDK sharedSDK].conversationManager saveMessage:message forSession:session completion:nil];
//            NSString *strSessionName = @"";
//            NIMUser *user = [[NIMSDK sharedSDK].userManager userInfo:strSessionId];
//            if ([user.alias length]) {
//                strSessionName = user.alias;
//            }else{
//                NIMUserInfo *userInfo = user.userInfo;
//                strSessionName = userInfo.nickName;
//            }
            
            //X
            //            NSString * tip = [NSString stringWithFormat:@"%@开启了朋友验证，你还不是他（她）朋友。请先发送朋友验证请求，对方验证通过后，才能聊天。发送朋友验证",strSessionName];
            //
            NSString * tip = @"not_friends_send_failed";
            NIMMessage *tipMessage = [self msgWithTip:tip];
            tipMessage.timestamp = message.timestamp+1;
            [[NIMSDK sharedSDK].conversationManager saveMessage:tipMessage forSession:session completion:nil];
            return NO;
        }
    }else{
        return YES;
    }
}

@end
