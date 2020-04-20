//
//  NIMMessageMaker.h
//  NIMKit
//
//  Created by chris.
//  Copyright (c) 2015年 NetEase. All rights reserved.
//

#import <Foundation/Foundation.h>
//#import <NIMSDK/NIMSDK.h>
#import "ImConfig.h"

@class NIMKitLocationPoint;

@interface NIMMessageMaker : NSObject
+ (NSString *)jsonStringWithDictionary:(NSDictionary *)dict;
+ (NIMMessage*_Nullable)msgWithText:(NSString*)text andApnsMembers:(NSArray *)members andeSession:(NIMSession *)session  apns:(nonnull  NSString *)apns;

+ (NIMMessage *_Nullable)msgWithAudio:(NSString *)filePath andeSession:(NIMSession *)session apns:(nonnull  NSString *)apns;

+ (NIMMessage *_Nullable)msgWithImage:(UIImage *)image andeSession:(NIMSession *)session apns:(nonnull  NSString *)apns;

+ (NIMMessage *_Nullable)msgWithImagePath:(NSString *)path andeSession:(NIMSession *)session apns:(nonnull  NSString *)apns;

+ (NIMMessage *_Nullable)msgWithVideo:(NSString *)filePath andeSession:(NIMSession *)session apns:(nonnull  NSString *)apns;

+ (NIMMessage *_Nullable)msgWithLocation:(NIMKitLocationPoint*)locationPoint andeSession:(NIMSession *)session apns:(nonnull  NSString *)apns;

+ (NIMMessage*_Nullable)msgWithCustom:(NIMObject *)attachment andeSession:(NIMSession *)session apns:(nonnull  NSString *)apns;

+ (NIMMessage*_Nullable)msgWithCustomAttachment:(DWCustomAttachment *)attachment andeSession:(NIMSession *)session apns:(nonnull  NSString *)apns;
+ (NSMutableDictionary*)makeApnsPayload:(NSString *) type payloadData:(NSDictionary *)payloadData sound:(NSString *)sound;
@end
