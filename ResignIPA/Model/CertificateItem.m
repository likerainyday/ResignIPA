//
//  CertificateItem.m
//  Resign IPA
//
//  Created by wangyong on 2017/4/13.
//  Copyright © 2017年 wyong.developer. All rights reserved.
//

#import "CertificateItem.h"

@implementation CertificateItem

-(BOOL)isEqual:(id)object{
    
    BOOL isEqual =NO;
    CertificateItem *item =object;
    
    if (item !=nil && [item isKindOfClass:[CertificateItem class]]) {
        if ([item.sha1 isEqualToString:self.sha1]) {
            isEqual =YES;
        }
    }
    return isEqual;
}


-(instancetype)initWithString:(NSString *)tempString{
    if (self=[super init]) {
        //start at fisrt ')'
        NSRange range = [tempString rangeOfString:@")"];
        if (range.location != NSNotFound) {
            NSString *realString = [tempString substringFromIndex:range.location+range.length];
            if (realString) {
                NSArray *items =[realString componentsSeparatedByString:@"\""];
                if (items && items.count==3) {
                    _name =[items objectAtIndex:1];
                    _sha1 =[[items objectAtIndex:0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                }
            }
        }
    }
    return self;
}

@end
