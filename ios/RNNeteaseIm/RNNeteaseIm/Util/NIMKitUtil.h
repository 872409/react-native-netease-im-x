//
//  NIMUtil.h
//  NIMKit
//
//  Created by chris on 15/8/10.
//  Copyright (c) 2015年 NetEase. All rights reserved.
//

#import <Foundation/Foundation.h>
//#import <NIMSDK/NIMSDK.h>
#import "ImConfig.h"


@interface NIMKitUtil : NSObject

+ (NSString *)showNick:(NSString *)uid inMessage:(NIMMessage *)message;

+ (NSString *)showNick:(NSString *)uid inSession:(NIMSession *)session;

+ (NSString *)showTime:(NSTimeInterval)msglastTime showDetail:(BOOL)showDetail;

//X
+ (NSString *)messageTipContent2:(NIMMessage *)message result:(NSMutableDictionary *) result;
+ (NSString *)messageTipContent:(NIMMessage *)message;

+ (BOOL)canEditTeamInfo:(NIMTeamMember *)member;

+ (BOOL)canInviteMember:(NIMTeamMember *)member;

//X
+ (NSString*)teamNotificationFormatedMessage2:(NIMMessage *)message  result:(NSMutableDictionary *) result;
+ (NSString*)teamNotificationFormatedMessage:(NIMMessage *)message;


@end
