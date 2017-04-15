//
//  ResignManager.h
//  Resign IPA
//
//  Created by wangyong on 2017/4/13.
//  Copyright © 2017年 wyong.developer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AppInfoItem.h"

@interface ResignManager : NSObject

+(ResignManager *)manager;

+(BOOL)canResign;

+(void)executeTask:(NSString *)taskPath arguments:(NSArray *)arguments currentPath:(NSString *)currentPath completion:(void(^)(NSString *result))callback;

+(void)getCertificates:(void(^)(NSArray <CertificateItem*>*))callback;

+(void)getProvisioningProfiles:(void(^)(NSArray <ProvisioningProfileItem*>*))callback;

+(NSString *)analysisChoseIpaFile:(NSString *)filePath completion:(void(^)(AppInfoItem *item))callback;

+(void)resignIPA:(AppInfoItem *)item completion:(void(^)(NSString *message))callback;

@end
