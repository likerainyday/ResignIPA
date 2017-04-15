//
//  CertificateItem.h
//  Resign IPA
//
//  Created by wangyong on 2017/4/13.
//  Copyright © 2017年 wyong.developer. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CertificateItem : NSObject

@property (copy, readonly) NSString *name;

@property (copy, readonly) NSString *sha1;

-(instancetype)initWithString:(NSString *)tempString;

@end
