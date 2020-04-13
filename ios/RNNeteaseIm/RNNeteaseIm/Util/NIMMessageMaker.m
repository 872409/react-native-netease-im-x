//
//  NIMMessageMaker.m
//  NIMKit
//
//  Created by chris.
//  Copyright (c) 2015年 NetEase. All rights reserved.
//

#import "NIMMessageMaker.h"
#import "NSString+NIMKit.h"
#import "NIMKitLocationPoint.h"

@implementation NIMMessageMaker

+ (NIMMessage*)msgWithText:(NSString*)text andApnsMembers:(NSArray *)members andeSession:(NIMSession *)session apns:(nonnull  NSString *)apns
{

    NIMMessage *message = [[NIMMessage alloc] init];
    message.text    = text;
//    message.apnsContent = text;
    if (members.count) {
        NIMMessageApnsMemberOption *apnsMemberOption = [[NIMMessageApnsMemberOption alloc]init];
        apnsMemberOption.userIds = members;
        apnsMemberOption.forcePush = YES;
        apnsMemberOption.apnsContent = apns;//@"有人@了你";
        message.apnsMemberOption = apnsMemberOption;
    }
    message.apnsContent = text;
    [NIMMessageMaker setupMessagePushBody:message andSession:session];
    return message;
}

+ (NIMMessage*)msgWithAudio:(NSString*)filePath andeSession:(NIMSession *)session apns:(nonnull  NSString *)apns
{
    NIMAudioObject *audioObject = [[NIMAudioObject alloc] initWithSourcePath:filePath];
    NIMMessage *message = [[NIMMessage alloc] init];
    message.messageObject = audioObject;
    message.text = apns;// @"发来了一段语音";
    [NIMMessageMaker setupMessagePushBody:message andSession:session];
    return message;
}
+ (NIMMessage*)msgWithCustom:(NIMObject *)attachment andeSession:(NIMSession *)session apns:(nonnull  NSString *)apns
{

    NIMMessage *message               = [[NIMMessage alloc] init];
    NIMCustomObject *customObject     = [[NIMCustomObject alloc] init];
    customObject.attachment           = attachment;
    message.messageObject             = customObject;
    message.apnsContent = apns;//@"发来了一条未知消息";
    [NIMMessageMaker setupMessagePushBody:message andSession:session];
    return message;
}
+ (NIMMessage*)msgWithCustomAttachment:(DWCustomAttachment *)attachment andeSession:(NIMSession *)session apns:(nonnull  NSString *)apns
{

    NIMMessage *message               = [[NIMMessage alloc] init];
    NIMCustomObject *customObject     = [[NIMCustomObject alloc] init];
    customObject.attachment           = attachment;
    message.messageObject             = customObject;
    NSString *text = @"";
    
    if(attachment.custTypeStr == nil || [attachment.custTypeStr length]==0){
        attachment.custTypeStr = [NSString stringWithFormat:@"%zd",attachment.custType];
    }
    
    switch (attachment.custType) {
        case CustomMessgeTypeRedpacket:
            text = [NSString stringWithFormat:@"[红包]%@", [attachment.dataDict objectForKey:@"comments"]];
            break;
        case CustomMessgeTypeRTCCall:
            text = @"rtcCall";
            break;
        case CustomMessgeTypeBankTransfer:
            text = [NSString stringWithFormat:@"[转账]%@", [attachment.dataDict objectForKey:@"comments"]];
            break;
        case CustomMessgeTypeUrl:
            text = [attachment.dataDict objectForKey:@"title"];
            break;
        case CustomMessgeTypeAccountNotice:
            text = [attachment.dataDict objectForKey:@"title"];
            break;
        case CustomMessgeTypeRedPacketOpenMessage:{
            text = @"";
            NIMMessageSetting *seting = [[NIMMessageSetting alloc]init];
            seting.apnsEnabled = NO;
            seting.shouldBeCounted = NO;
            message.setting = seting;
        }
            break;
        case CustomMessgeTypeBusinessCard: //名片
        {
            text = [NSString stringWithFormat:@"[名片]%@", [attachment.dataDict objectForKey:@"name"]];
        }
            break;
        case CustomMessgeTypeCustom: //自定义
        {
            text = [NSString stringWithFormat:@"%@", [attachment.dataDict objectForKey:@"pushContent"]];
        }
            break;
        default:
            text = attachment.custTypeStr;
            break;
    }
    message.apnsContent = apns;
    [NIMMessageMaker setupMessagePushBody:message andSession:session];
    return message;
}

+ (NIMMessage*)msgWithVideo:(NSString*)filePath andeSession:(NIMSession *)session  apns:(nonnull  NSString *)apns
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm"];
    NSString *dateString = [dateFormatter stringFromDate:[NSDate date]];
    NIMVideoObject *videoObject = [[NIMVideoObject alloc] initWithSourcePath:filePath];
    videoObject.displayName = [NSString stringWithFormat:@"视频发送于%@",dateString];
    NIMMessage *message = [[NIMMessage alloc] init];
    message.messageObject = videoObject;
    message.apnsContent = apns;//@"发来了一段视频";
    [NIMMessageMaker setupMessagePushBody:message andSession:session];
    return message;
}
+ (NIMMessage*)msgWithImage:(UIImage*)image andeSession:(NIMSession *)session apns:(nonnull  NSString *)apns
{
    NIMImageObject *imageObject = [[NIMImageObject alloc] initWithImage:image];
    NIMImageOption *option  = [[NIMImageOption alloc] init];
    option.compressQuality  = 1;
    imageObject.option      = option;
    return [NIMMessageMaker generateImageMessage:imageObject andeSession:session apns:apns];
}

+ (NIMMessage *)msgWithImagePath:(NSString*)path andeSession:(NIMSession *)session apns:(nonnull  NSString *)apns
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm"];
    NSString *dateString = [dateFormatter stringFromDate:[NSDate date]];
    NIMImageObject * imageObject = [[NIMImageObject alloc] initWithFilepath:path];
    imageObject.displayName = [NSString stringWithFormat:@"图片发送于%@",dateString];
    NIMMessage *message     = [[NIMMessage alloc] init];
    message.messageObject   = imageObject;
    message.apnsContent =  apns;//@"发来一张图片";
//    message.apnsContent = [NIMMessageMaker jsonStringWithDictionary:@{@"loc-key":@"IM_RECEIVE_IMAGE",@"loc-args":@"XX"}];
    return [NIMMessageMaker generateImageMessage:imageObject  andeSession:session apns:apns];
}

+ (NIMMessage *)generateImageMessage:(NIMImageObject *)imageObject andeSession:(NIMSession *)session apns:(nonnull  NSString *)apns
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm"];
    NSString *dateString = [dateFormatter stringFromDate:[NSDate date]];
    imageObject.displayName = [NSString stringWithFormat:@"图片发送于%@",dateString];
    NIMMessage *message     = [[NIMMessage alloc] init];
    message.messageObject   = imageObject;
    message.apnsContent =  apns;//@"发来一张图片";
//    message.apnsContent = [NIMMessageMaker jsonStringWithDictionary:@{@"loc-key":@"IM_RECEIVE_IMAGE",@"loc-args":@"XX"}];
    [NIMMessageMaker setupMessagePushBody:message andSession:session];
    return message;
}

+ (NSString *)jsonStringWithDictionary:(NSDictionary *)dict
{
    if (dict && 0 != dict.count)
    {
        NSError *error = nil;
        // NSJSONWritingOptions 是"NSJSONWritingPrettyPrinted"的话有换位符\n；是"0"的话没有换位符\n。
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        return jsonString;
    }
    
    return nil;
}

+ (NIMMessage*)msgWithLocation:(NIMKitLocationPoint *)locationPoint andeSession:(NIMSession *)session  apns:(nonnull  NSString *)apns{
    NIMLocationObject *locationObject = [[NIMLocationObject alloc] initWithLatitude:locationPoint.coordinate.latitude
                                                                          longitude:locationPoint.coordinate.longitude
                                                                              title:locationPoint.title];
    NIMMessage *message               = [[NIMMessage alloc] init];
    message.messageObject             = locationObject;
    message.apnsContent =  apns;//@"发来了一条位置信息";
    [NIMMessageMaker setupMessagePushBody:message andSession:session];
    return message;
}

+ (NSMutableDictionary *)makeApnsPayload:(NSString *) type payloadData:(NSDictionary *)payloadData sound:(NSString *)sound{
    
    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    [payload setObject:[sound length]?sound:@"default" forKey:@"sound"];
    [payload setObject:type forKey:@"type"];
    [payload setObject:payloadData forKey:@"payload"];
    return payload;
}

+ (void)setupMessagePushBody:(NIMMessage *)message andSession:(NIMSession *)session{
//    NSMutableDictionary *payload = [NSMutableDictionary dictionary];
    NSString *strSessionID = @"";
    if (session.sessionType == NIMSessionTypeP2P) {//点对点
        strSessionID = [NIMSDK sharedSDK].loginManager.currentAccount;
    }else{
        strSessionID = [NSString stringWithFormat:@"%@",session.sessionId];
    }
    NSString *strSessionType = [NSString stringWithFormat:@"%zd",session.sessionType];
    NSMutableDictionary *payload  = [NIMMessageMaker makeApnsPayload:APNsTypeConversationMsg payloadData:@{@"sessionId":strSessionID,@"sessionType":strSessionType} sound:@""];
    
    message.apnsPayload = payload;
//    id json = [NIMMessageMaker jsonStringWithDictionary:payload];
//    NSLog(@"apnsPlayload:%@",json);

//     NIMMessageSetting *seting = [[NIMMessageSetting alloc]init];
//     seting.apnsEnabled = YES;
//     seting.shouldBeCounted = YES;
//     message.setting = seting;
}

@end
