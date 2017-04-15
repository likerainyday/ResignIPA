//
//  ProvisioningProfileItem.h
//  Resign IPA
//
//  Created by wangyong on 2017/4/13.
//  Copyright © 2017年 wyong.developer. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 Properties Of Provisioning Profile
 */
@interface ProvisioningProfileItem : NSObject

@property (copy, readonly) NSString *name;

@property (copy, readonly) NSString *teamName;

@property (copy, readonly) NSString *valid;

@property (assign, readonly) NSString *debug;

@property (copy, readonly) NSString *UUID;

@property (copy, readonly) NSArray *devices;

@property (assign, readonly) NSInteger timeToLive;

@property (copy, readonly) NSString *applicationIdentifier;

@property (copy, readonly) NSString *bundleIdentifier;

@property (copy, readonly) NSArray *certificates;

@property (assign, readonly) NSInteger version;

@property (copy, readonly) NSDate *creationDate;

@property (copy, readonly) NSDate *expirationDate;

@property (assign, readonly) NSArray *prefixes;

@property (copy, readonly) NSString *appIdName;

@property (copy, readonly) NSString *teamIdentifier;

@property (copy, readonly) NSString *filePath;

-(instancetype)initWithFilePath:(NSString *)filePath;

@end
