//
//  ViewController.m
//  Resign IPA
//
//  Created by wangyong on 2017/4/13.
//  Copyright © 2017年 wyong.developer. All rights reserved.
//

#import "ViewController.h"
#import "ResignManager.h"
#import "AppDelegate.h"

@interface ViewController ()<NSComboBoxDataSource,NSComboBoxDelegate>

@property (weak) IBOutlet NSComboBox *cerComboBox;
@property (weak) IBOutlet NSComboBox *profileComboBox;
@property (weak) IBOutlet NSTextField *txtIPAPath,*txtBundleId,*txtAppName,*txtAppVersion,*txtBundleVersion;
@property (strong) IBOutlet NSTextView *logTextView;

@property (strong) NSArray *arrayOfCerts;
@property (strong) NSArray *arrayOfProfile;

@property(strong) AppInfoItem *editItem;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self setup];
    [self loadCertsAndProfiles];
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
    // Update the view, if already loaded.
}

-(void)setup{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textDidChanged:) name:NSControlTextDidChangeNotification object:self.txtIPAPath];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textDidChanged:) name:NSControlTextDidChangeNotification object:self.txtBundleId];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textDidChanged:) name:NSControlTextDidChangeNotification object:self.txtAppName];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textDidChanged:) name:NSControlTextDidChangeNotification object:self.txtAppVersion];
}

#pragma mark -loadCersAndProfilesOfDevice

-(void)loadCertsAndProfiles{

    [self logOperation:@"welcome use Resign IPA ..."];
    [self logOperation:@"start load certificates on this Mac..."];
    [self logOperation:@"start load provisioning profiles on this Mac..."];

    [ResignManager getCertificates:^(NSArray<CertificateItem *> *certs) {
        self.arrayOfCerts =[[NSArray alloc]initWithArray:certs];
        [self.profileComboBox reloadData];
        [self logOperation:@"certificates did load."];
    }];

    [ResignManager getProvisioningProfiles:^(NSArray<ProvisioningProfileItem*> *profiles){
        self.arrayOfProfile =[[NSArray alloc]initWithArray:profiles];
        [self.profileComboBox reloadData];
        [self logOperation:@"provisioning profiles did load."];
    }];
}

#pragma mark -buttonAction

-(IBAction)chooseIPABtnPressed:(id)sender{
    
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setCanChooseDirectories:NO];
    [panel setAllowsMultipleSelection:NO];
    [panel setCanChooseFiles:YES];
    [panel setAllowsOtherFileTypes:NO];
    [panel setAllowedFileTypes:@[@"ipa", @"IPA"]];
    
    [panel beginSheetModalForWindow:self.view.window completionHandler:^(NSInteger result){
        if (result ==NSModalResponseOK) {
            [self.txtIPAPath setStringValue:[panel.URL path]];
            [self analysisChoseIPA];
        }
    }];
}

-(IBAction)resignBtnPressed:(id)sender{
    //check
    if (![ResignManager canResign]) {
        [self showAlert:@"Invalid Ipa File,Please check."];
    }else if ([self.cerComboBox indexOfSelectedItem] <0){
        [self showAlert:@"Please Select a aiviable certificate"];
    }else if ([self.profileComboBox indexOfSelectedItem] <0){
        [self showAlert:@"Please Select a aiviable profile"];
    }else{
        [ResignManager resignIPA:self.editItem completion:^(NSString *error) {
            [self logOperation:error];
        }];
    }
}

#pragma mark -functions

-(void)analysisChoseIPA{
        
   NSString *logsString =[ResignManager analysisChoseIpaFile:self.txtIPAPath.stringValue completion:^(AppInfoItem *item) {
       [self logOperation:@"end unzip ipa file"];
        if (item) {
            //show primary app info
            self.txtAppName.placeholderString =item.name;
            self.txtBundleId.placeholderString =item.bundleId;
            self.txtAppVersion.placeholderString =item.version;
            self.txtBundleVersion.placeholderString =item.bundleVersion;
            //show primary app provisioning profile info
            self.cerComboBox.placeholderString =item.profile.teamName;
            self.profileComboBox.placeholderString =item.profile.name;
        }
    }];
    if (logsString) {
        [self logOperation:logsString];
    }
}

-(void)logOperation:(NSString *)string{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *newValue = [self.logTextView.textStorage.mutableString stringByAppendingFormat:@"\n%@", string];
        [self.logTextView setString:newValue];
    });
}

#pragma mark -NSComboBoxDataSource,NSComboBoxDelegate

- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)comboBox{
    if (comboBox==self.profileComboBox) {
        return self.arrayOfProfile.count;
    }
    return self.arrayOfCerts.count;
}

- (id)comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(NSInteger)index{
    
    id result = nil;
    
    if (aComboBox==self.profileComboBox){
        ProvisioningProfileItem *item =[self.arrayOfProfile objectAtIndex:index];
        result =item.name;
    }else if (aComboBox==self.cerComboBox){
        CertificateItem *item =[self.arrayOfCerts objectAtIndex:index];
        result =item.name;
    }
    return result;
}

- (void)comboBoxSelectionDidChange:(NSNotification *)notification{
    
    if (self.editItem==nil) {
        self.editItem =[[AppInfoItem alloc]init];
    }
    NSComboBox *comboBox = (NSComboBox *)[notification object];
    if (comboBox==self.profileComboBox){
        ProvisioningProfileItem *item =[self.arrayOfProfile objectAtIndex:comboBox.indexOfSelectedItem];
        self.editItem.profile =item;
        self.txtBundleId.stringValue =item.bundleIdentifier;
    }else if (comboBox==self.cerComboBox){
        CertificateItem *item =[self.arrayOfCerts objectAtIndex:comboBox.indexOfSelectedItem];
        self.editItem.certificate =item;
    }
}

#pragma mark -textDidChanged

-(void)textDidChanged:(NSNotification *)notification{

    NSTextField *textField =(NSTextField *)notification.object;

    if (self.editItem==nil) {
        self.editItem =[[AppInfoItem alloc]init];
    }
    if (self.txtIPAPath==textField) {
        [self analysisChoseIPA];
    }
    else if (self.txtBundleId==textField){
        self.editItem.bundleId =textField.stringValue;
    }
    else if (self.txtAppName==textField){
        self.editItem.name =textField.stringValue;
    }
    else if (self.txtAppVersion==textField){
        self.editItem.version =textField.stringValue;
    }
    else if (self.txtBundleVersion==textField){
        self.editItem.bundleVersion =textField.stringValue;
    }
}

-(void)showAlert:(NSString *)alertString{
    NSAlert *alert =[[NSAlert alloc]init];
    [alert setMessageText:alertString];
    [alert beginSheetModalForWindow:self.view.window completionHandler:NULL];
}

@end
