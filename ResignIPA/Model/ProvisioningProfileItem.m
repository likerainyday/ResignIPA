//
//  ProvisioningProfileItem.m
//  Resign IPA
//
//  Created by wangyong on 2017/4/13.
//  Copyright © 2017年 wyong.developer. All rights reserved.
//

#import "ProvisioningProfileItem.h"

@implementation ProvisioningProfileItem

-(instancetype)initWithFilePath:(NSString *)filePath{
    if (self=[super init]) {
        _filePath =filePath;
        [self analysisProvisioningProfile];
    }
    return self;
}

-(void)analysisProvisioningProfile{

    NSDictionary *properties = nil;
    
    CMSDecoderRef decoder = NULL;
    CFDataRef dataRef = NULL;
    @try {
        CMSDecoderCreate(&decoder);
        NSData *fileData = [NSData dataWithContentsOfFile:_filePath];
        CMSDecoderUpdateMessage(decoder, fileData.bytes, fileData.length);
        CMSDecoderFinalizeMessage(decoder);
        CMSDecoderCopyContent(decoder, &dataRef);
        NSString *plistString =[[NSString alloc] initWithData:(__bridge NSData *)dataRef encoding:NSUTF8StringEncoding];
        NSData *plistData =[plistString dataUsingEncoding:NSUTF8StringEncoding];
        properties = [NSPropertyListSerialization propertyListWithData:plistData options:NSPropertyListImmutable format:nil error:nil];
    }
    @catch (NSException *exception) {
        NSLog(@"Could not decode file.\n");
    }
    @finally {
        if (decoder) CFRelease(decoder);
        if (dataRef) CFRelease(dataRef);
    }
    if (properties) {
        NSDictionary *entitlements =[properties objectForKey:@"Entitlements"];
        _appIdName =[properties objectForKey:@"AppIDName"]?:@"Unknown";
        _teamIdentifier = [entitlements objectForKey:@"com.apple.developer.team-identifier"]?:@"Unknown";
        _name = [properties objectForKey:@"Name"]?:@"Unknown";
        _teamName =[properties objectForKey:@"TeamName"]?:@"Unknown";
        _debug =[[entitlements objectForKey:@"get-task-allow"] isEqualToNumber:@(1)] ? @"YES" : @"NO";
        _creationDate =[properties objectForKey:@"CreationDate"]?:@"Unknown";
        _expirationDate =[properties objectForKey:@"ExpirationDate"]?:@"Unknown";
        _devices =[properties objectForKey:@"ProvisionedDevices"]?:@"Unknown";
        _timeToLive =[[properties objectForKey:@"TimeToLive"] integerValue];
        _applicationIdentifier =[entitlements objectForKey:@"application-identifier"]?:@"Unknown";
        _certificates =[properties objectForKey:@"DeveloperCertificates"]?:@"Unknown";
        _valid = ([[NSDate date] timeIntervalSinceDate:self.expirationDate] > 0) ? @"NO" : @"YES";
        _version =[[properties objectForKey:@"Version"] integerValue];
        _UUID =[properties objectForKey:@"UUID"]?:@"Unknown";
        _prefixes =[properties objectForKey:@"ApplicationIdentifierPrefix"];
        for (NSString *prefix in _prefixes) {
            NSRange range = [_applicationIdentifier rangeOfString:[NSString stringWithFormat:@"%@.", prefix]];
            if (range.location != NSNotFound){
                NSInteger startIndex =range.location+range.length;
                _bundleIdentifier = [_applicationIdentifier substringFromIndex:startIndex];
                break;
            }
        }
        if (_bundleIdentifier==nil) {
            _bundleIdentifier =_applicationIdentifier;
        }
    }
}

@end
