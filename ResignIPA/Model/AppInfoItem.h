//
//  AppInfoItem.h
//  Resign IPA
//
//  Created by wangyong on 2017/4/13.
//  Copyright © 2017年 wyong.developer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CertificateItem.h"
#import "ProvisioningProfileItem.h"

@interface AppInfoItem : NSObject

@property(copy) NSString *name;

@property(copy) NSString *bundleId;

@property(copy) NSString *version;

@property(copy) NSString *bundleVersion;

@property(copy) NSString *deploymentTarget;

@property(copy) NSString *originalFilePath;

@property(copy) NSString *tempWorkspace;

@property(copy) NSString *tempAppFilePath;

@property(copy) NSString *tempInfoPlistPath;

@property(strong) CertificateItem *certificate;

@property(strong) ProvisioningProfileItem *profile;

@end
