//
//  ResignManager.m
//  Resign IPA
//
//  Created by wangyong on 2017/4/13.
//  Copyright © 2017年 wyong.developer. All rights reserved.
//

#import "ResignManager.h"

static NSString *const kUnzipPath =@"/usr/bin/unzip";
static NSString *const kSecurityPath = @"/usr/bin/security";
static NSString *const kDefaultsPath = @"/usr/bin/defaults";
static NSString *const kChmodPath = @"/bin/chmod";
static NSString * const kCodesignPath = @"/usr/bin/codesign";
static NSString * const kZipPath = @"/usr/bin/zip";
static NSString * const kRMPath = @"/bin/rm";
static NSString * const kOpenPath = @"/usr/bin/open";

static NSString * const kEntitlementsFileName = @"entitlements.plist";
static NSString *const kProvisioningProfileFilePath = @"Library/MobileDevice/Provisioning Profiles";

@interface ResignManager ()

@property(strong) AppInfoItem *originalItem;

@property(strong) dispatch_queue_t task_queue;

@end

@implementation ResignManager

+(ResignManager *)manager{
    static ResignManager *manager =nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager =[[ResignManager alloc]init];
        manager.task_queue =dispatch_queue_create("com.wyong.task.queue", DISPATCH_QUEUE_CONCURRENT);
    });
    return manager;
}

+(BOOL)canResign{
    return [ResignManager manager]->_originalItem !=nil;
}

+(void)getCertificates:(void(^)(NSArray <CertificateItem*>*))callback{

    [self.class executeTask:kSecurityPath arguments:@[@"find-identity", @"-v", @"-p", @"codesigning"] currentPath:nil completion:^(NSString *result) {
        NSMutableArray *certificates = [NSMutableArray array];
        NSArray *components = [result componentsSeparatedByString:@"\n"];
        for (NSString *string in components) {
            CertificateItem *item =[[CertificateItem alloc]initWithString:string];
            if (item.name) {
                [certificates addObject:item];
            }
        }
        callback(certificates);
    }];
}

+(void)getProvisioningProfiles:(void(^)(NSArray <ProvisioningProfileItem*>*))callback{

    NSMutableArray *profiles =[NSMutableArray new];
    
    NSString *filePath =[NSHomeDirectory() stringByAppendingPathComponent:kProvisioningProfileFilePath];
    NSFileManager *fileManager =[NSFileManager defaultManager];
    NSArray *subFiles =[fileManager contentsOfDirectoryAtPath:filePath error:nil];
    subFiles =[subFiles filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"pathExtension IN %@", @[@"mobileprovision", @"provisionprofile"]]];
    for (NSString *fileName in subFiles) {
        NSString *profilePath =[filePath stringByAppendingPathComponent:fileName];
        ProvisioningProfileItem *item =[[ProvisioningProfileItem alloc]initWithFilePath:profilePath];
        if (item.name) {
            [profiles addObject:item];
        }
    }
    callback(profiles);
}

+(NSString *)analysisChoseIpaFile:(NSString *)filePath completion:(void(^)(AppInfoItem *item))callback{
    
    NSString *fileType =[filePath pathExtension].lowercaseString;
    if (![@"ipa" isEqualToString:fileType]) {
       [ResignManager manager]->_originalItem = nil;
        return @"not a ipa file";
    }
    NSFileManager *fileManager =[NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:filePath]) {
        [ResignManager manager]->_originalItem = nil;
        return @"ipa file not exist";
    }
    NSString *tempWorkspace = [NSTemporaryDirectory() stringByAppendingString:[[NSBundle mainBundle]bundleIdentifier]];
    if ([fileManager fileExistsAtPath:tempWorkspace]) {
        NSArray *subFiles =[fileManager contentsOfDirectoryAtPath:tempWorkspace error:nil];
        for (NSString *fileName in subFiles) {
            NSString *realPath =[tempWorkspace stringByAppendingPathComponent:fileName];
            [fileManager removeItemAtPath:realPath error:nil];
        }
    }else{
        [fileManager createDirectoryAtPath:tempWorkspace withIntermediateDirectories:YES attributes:nil error:nil];
    }
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    [self.class executeTask:kUnzipPath arguments:@[@"-q", filePath, @"-d", tempWorkspace] currentPath:nil completion:^(NSString *result) {
        NSString *payloadPath =[tempWorkspace stringByAppendingPathComponent:@"Payload"];
        NSArray *subFiles = [fileManager contentsOfDirectoryAtPath:payloadPath error:nil];
        for (NSString *fileName in subFiles) {
            if ([@"app" isEqualToString:[fileName pathExtension].lowercaseString]) {
                AppInfoItem *item =[[AppInfoItem alloc]init];
                item.originalFilePath =filePath;
                item.tempWorkspace =tempWorkspace;
                //unzip app file path
                NSString *tempAppFilePath =[NSString stringWithFormat:@"%@/Payload/%@",tempWorkspace,fileName];
                item.tempAppFilePath =tempAppFilePath;
                //seach for profile path
                NSArray *provisioningProfiles = [fileManager contentsOfDirectoryAtPath:tempAppFilePath error:nil];
                provisioningProfiles = [provisioningProfiles filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"pathExtension IN %@", @[@"mobileprovision", @"provisionprofile"]]];
                for (NSString *path in provisioningProfiles){
                    if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@", tempAppFilePath, path] isDirectory:NO]){
                        NSString *profilePath  =[NSString stringWithFormat:@"%@/%@", tempAppFilePath, path];
                        item.profile =[[ProvisioningProfileItem alloc]initWithFilePath:profilePath];
                        break;
                    }else{
                        item.profile =nil;
                    }
                }
                //unzip app info.plist path
                item.tempInfoPlistPath =[tempAppFilePath stringByAppendingPathComponent:@"Info.plist"];
                NSDictionary *dict =[[NSDictionary alloc]initWithContentsOfFile:[tempAppFilePath stringByAppendingPathComponent:@"Info.plist"]];
                item.name =[dict objectForKey:@"CFBundleDisplayName"];
                item.bundleId =[dict objectForKey:@"CFBundleIdentifier"];
                item.version =[dict objectForKey:@"CFBundleShortVersionString"];
                item.bundleVersion =[dict objectForKey:@"CFBundleVersion"];
                [ResignManager manager]->_originalItem =item;
                callback(item);
                break;
            }
        }
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    return nil;
}

+(void)resignIPA:(AppInfoItem *)item completion:(void(^)(NSString *message))callback{

    ResignManager *manager =[ResignManager manager];
    NSString *workspacePath =manager.originalItem.tempWorkspace;
    if (workspacePath==nil || workspacePath.length==0) {
        callback(@"Unzip file not find");
        return;
    }
    NSString *infoPlistPath =manager.originalItem.tempInfoPlistPath;
    if (infoPlistPath==nil || infoPlistPath.length==0) {
        callback(@"Info.plist file not find");
        return;
    }
    NSString *appPath =manager.originalItem.tempAppFilePath;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    //create entitlements.plist file
    NSString *profilePath =[item.profile filePath];
    if (![[NSFileManager defaultManager] fileExistsAtPath:profilePath]) {
        callback(@"provisioning profile not find");
        return;
    }
    [self.class executeTask:kSecurityPath arguments:@[@"cms", @"-D", @"-i", profilePath] currentPath:nil completion:^(NSString *result) {
        NSString *xmlStartStr = @"<?xml";
        NSRange range = [result rangeOfString:xmlStartStr];
        if (range.location != NSNotFound) {
            result = [result substringFromIndex: range.location];
        }
        NSDictionary *plistDic = result.propertyList;
        //get Entitlements dictionary
        NSDictionary *entitlementsDict =[plistDic objectForKey:@"Entitlements"];
        if (entitlementsDict) {
            NSString *eltFilePath = [workspacePath stringByAppendingPathComponent:kEntitlementsFileName];
            [entitlementsDict writeToFile:eltFilePath atomically:YES];
        }
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    //remove
    NSString *watchPath =[appPath stringByAppendingPathComponent:@"Watch"];
    [self.class executeTask:kRMPath arguments:@[@"-fr", watchPath] currentPath:nil completion:^(NSString *result) {
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSString *plugInsPath =[appPath stringByAppendingPathComponent:@"PlugIns"];
    [self.class executeTask:kRMPath arguments:@[@"-fr", plugInsPath] currentPath:nil completion:^(NSString *result) {
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    //getExecutableFile
    __block NSString *executableFileName =nil;
    [self.class executeTask:kDefaultsPath arguments:@[@"read", infoPlistPath, @"CFBundleExecutable"] currentPath:nil completion:^(NSString *result) {
        executableFileName =[result stringByReplacingOccurrencesOfString:@"\n" withString:@""];
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    if (executableFileName==nil) {
        callback(@"ExecutableFile not find");
        return;
    }
    NSString *executableFilePath =[appPath stringByAppendingPathComponent:executableFileName];
    //changeExecutableMode
    [self.class executeTask:kChmodPath arguments:@[@"755", executableFilePath] currentPath:nil completion:^(NSString *result) {
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    //writeBundleId
    if (item.bundleId.length>0) {
        [self.class executeTask:kDefaultsPath arguments:@[@"write", infoPlistPath, @"CFBundleIdentifier", item.bundleId] currentPath:nil completion:^(NSString *result) {
            dispatch_semaphore_signal(semaphore);
        }];
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    }
    //writeAppName
    if (item.name.length>0) {
        [self.class executeTask:kDefaultsPath arguments:@[@"write", infoPlistPath, @"CFBundleDisplayName", item.name] currentPath:nil completion:^(NSString *result) {
            dispatch_semaphore_signal(semaphore);
        }];
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    }
    //writeAppVersion
    if (item.version.length>0) {
        [self.class executeTask:kDefaultsPath arguments:@[@"write", infoPlistPath, @"CFBundleShortVersionString", item.version] currentPath:nil completion:^(NSString *result) {
            dispatch_semaphore_signal(semaphore);
        }];
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    }
    //writeBundleVersion
    if (item.bundleVersion.length>0) {
        [self.class executeTask:kDefaultsPath arguments:@[@"write", infoPlistPath, @"CFBundleVersion", item.bundleVersion] currentPath:nil completion:^(NSString *result) {
            dispatch_semaphore_signal(semaphore);
        }];
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    }
    NSString *certName =item.certificate.name;
    NSString *eltFilePath =[manager.originalItem.tempWorkspace stringByAppendingPathComponent:kEntitlementsFileName];
    NSString *entString = [NSString stringWithFormat:@"--entitlements=%@",eltFilePath];
    //resignIPA
    [self.class executeTask:kCodesignPath arguments:@[@"-vvv", @"-fs", certName, @"--no-strict", entString, appPath] currentPath:nil completion:^(NSString *result) {
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    //create new ipa file
    NSString *originalFilePath =[manager.originalItem.originalFilePath stringByDeletingLastPathComponent];
    NSString *originalFileName =[[manager.originalItem.originalFilePath lastPathComponent] stringByDeletingPathExtension];
    NSString *newFileName =[originalFileName stringByAppendingString:@"-Resgin.ipa"];
    NSString *newFilePath =[originalFilePath stringByAppendingPathComponent:newFileName];
    [self.class executeTask:kZipPath arguments:@[@"-qry", newFilePath, @"."] currentPath:workspacePath completion:^(NSString *result) {
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    //open file path
    NSString *folderPath =[manager.originalItem.originalFilePath stringByDeletingLastPathComponent];
    [ResignManager  executeTask:kOpenPath arguments:@[folderPath] currentPath:nil completion:nil];
}

#pragma mark -Task

+(void)executeTask:(NSString *)taskPath arguments:(NSArray *)arguments currentPath:(NSString *)currentPath completion:(void(^)(NSString *result))callback{

    NSTask *task =[[NSTask alloc] init];
    [task setLaunchPath:taskPath];
    [task setArguments:arguments];
    
    NSPipe *pipe = [[NSPipe alloc] init];
    [task setStandardOutput:pipe];
    [task setStandardError:pipe];
    
    if ([currentPath isKindOfClass:NSString.class]&&currentPath.length>0) {
        [task setCurrentDirectoryPath:currentPath];
    }
    __block NSFileHandle *handle = [pipe fileHandleForReading];
    
    dispatch_block_t taskBlock = ^{
        NSString *outputStr =[[NSString alloc] initWithData:[handle readDataToEndOfFile] encoding:NSASCIIStringEncoding];
        if (callback)
            callback(outputStr);
    };
    dispatch_async([ResignManager manager]->_task_queue, taskBlock);
    [task launch];
}

@end
