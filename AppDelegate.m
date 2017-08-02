//
//  AppDelegate.m
//  Tadacopy
//
//  Created by pvhieuz on 5/12/15.
//  Copyright (c) 2015 com.ac-lab.tadacopy. All rights reserved.
//

#import "AppDelegate.h"

#import <FBSDKCoreKit/FBSDKCoreKit.h>
#import "TDCBaseTabBarController.h"
#import "TDCBaseNavigationViewController.h"

#import "SCGenerateKey.h"
#import "SCAppId.h"
#import "TDCOpen.h"
#import "SCGenerateKey.h"

#import "SCLoginEmailController.h"
#import "TDCLoginViewController.h"
#import "SCRegisterController.h"

#import "TDCDeepLink.h"
#import "TDCSSOController.h"

#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>
#import <TwitterKit/TwitterKit.h>
#import "SCAuthTokens.h"
#import "TDCLoginEmailViewController.h"
#import "TDCCopyViewController.h"
#import "HorizontalSlideBanner.h"
#import "TDCFreecopyNaviController.h"
#import <AdSupport/AdSupport.h>
#import "ForceUpdate.h"

#define SCHEMA_URL      @"tadacopy"

@interface AppDelegate ()

@end

@implementation AppDelegate

static void exceptionHandler(NSException *exception){
    NSLog(@"ReproSample: Uncaught Exception: %@", [exception reason]);
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
//    // Override point for customization after application launch.
    
    DISPLAY_SCALE = SCALE;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateEmail:) name:@"update_mail" object:nil];
    
    NSSetUncaughtExceptionHandler(&exceptionHandler);
    [Repro setup:@"5cbefed1-878b-4260-bed4-4c91fc8eb663"];
    [Repro enableCrashReporting];
    [Repro startRecording];
    
    // Override point for customization after application launch.
    [SCModule shareInstanceModule];
    
    // generate uuid
    [[SCModule shareInstanceModule] generateUUID];
    
   
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifiDidRegisterProfileFinish:) name:@"DidFinishProfileUser" object:nil];
    
    [TwitterKit startWithConsumerKey:TWITTER_CUSTOMER_KEY consumerSecret:TWITTER_CUSTOMER_SECRET];
    
    [Fabric with:@[[Crashlytics class], [Twitter class]]];
    
    BOOL bNotRemoteNotifEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"bNotRemoteNotifEnabled"];
    if (!bNotRemoteNotifEnabled)
        [AppDelegate registerRemoteNotification];
    
    [self setNavigationBarStyle];
    
    if (launchOptions != nil) {
        NSDictionary *dictionary = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
        if (dictionary != nil) {
            NSLog(@"Launched from push notification: %@", dictionary);
            if (dictionary[@"page"] != nil) {
                [self handlePushNotification:dictionary];
            }
        }
    }
    
    // repro
    if(![USER_DEFAULTS boolForKey:@"device_count"]){
        [Repro track:@"Install" properties:nil];
        [USER_DEFAULTS setBool:YES forKey:@"device_count"];
    }
    
    ASIdentifierManager *im = [ASIdentifierManager sharedManager];
    NSLog(@"advertisingTrackingEnabled: %d", im.advertisingTrackingEnabled);
    NSLog(@"idfa: %@", im.advertisingIdentifier);
    
    NSString *idfa = @"";
    if (im.advertisingTrackingEnabled) {
        idfa = im.advertisingIdentifier.UUIDString;
    }
    NSLog(@"idfa string: %@", idfa);
    
    return [[FBSDKApplicationDelegate sharedInstance] application:application
                                    didFinishLaunchingWithOptions:launchOptions];
}

- (void)application:(UIApplication*)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData*)deviceToken {
    NSLog(@"My token is: %@", deviceToken);
    [Repro setPushDeviceToken:deviceToken];
}

- (void)application:(UIApplication*)application didFailToRegisterForRemoteNotificationsWithError:(NSError*)error {
    NSLog(@"Failed to get token, error: %@", error);
}

- (void)application:(UIApplication*)application didReceiveRemoteNotification:(NSDictionary*)userInfo {
    NSLog(@"Received notification: %@", userInfo);
    if (userInfo[@"page"] != nil) {
        [self handlePushNotification:userInfo];
    }
}

-(void)handlePushNotification:(NSDictionary*)params {
    BOOL userNil = [SHARED_SC_MODULE me];
    if (!userNil) {
        TDCBaseNavigationViewController *navController = (TDCBaseNavigationViewController *)self.window.rootViewController;
        TDCBaseTabBarController *tabBarController = navController.viewControllers[0];
        [TDCDeepLink initDeepLinkWithTabBarController:tabBarController andParameter:params];
    }
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    SHARED_SSO_CONTROLLER.bRegistering = false;
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    if (self.glResourceHandler) {
        // Delete OpenGL resources (e.g. framebuffer) of the SampleApp AR View
        [self.glResourceHandler freeOpenGLESResources];
        [self.glResourceHandler finishOpenGLESCommands];
    }
    if ([self.window.rootViewController isMemberOfClass:[TDCBaseNavigationViewController class]]) {
        TDCBaseNavigationViewController *navController = (TDCBaseNavigationViewController *)self.window.rootViewController;
        TDCBaseTabBarController *tabBarController = navController.viewControllers[0];
        if ([tabBarController isMemberOfClass:[TDCBaseTabBarController class]]) {
            TDCFreecopyNaviController *selectedNav = tabBarController.selectedViewController;
            if ([selectedNav.viewControllers[0] isMemberOfClass:[TDCCopyViewController class]]) {
                [((TDCCopyViewController*)selectedNav.viewControllers[0]).horizontalSlideBanner invalideateTimer];
            }
        }
    }
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    if(SHARED_SSO_CONTROLLER.bCheckingValidation)
        return;
    [ForceUpdate fetchNewVersionInformation:^(ForceUpdate *forceUpdate) {
        if (forceUpdate.force_update == true) {
            // update to new version
            [self showAlertForForceUpdate:[ForceUpdate getAppStoreURL]];
        }
        else {
            bool checkingValidation = SHARED_SSO_CONTROLLER.bCheckingValidation;
            bool bRegistering = SHARED_SSO_CONTROLLER.bRegistering;
            
            if (checkingValidation == false && bRegistering == false) {
                if (SHARED_SC_MODULE.userTokens.accessToken) {
                    [SVProgressHUD showWithMaskType:SVProgressHUDMaskTypeClear];
                    
                    [SHARED_SSO_CONTROLLER validateAccessToken:^(bool success) {
                        if (success) {
                            if (SHARED_SSO_CONTROLLER.mainUserName) {
                                [SVProgressHUD dismiss];
                                NSString *message = [NSString stringWithFormat:@"現在他のアプリでSmartCampus会員へログインされています。\t\nニックネーム：%@\t\nこちらの情報を使用してログインを行いますか？ （ゲストログインで使用していたアカウント情報は上書きされます）",SHARED_SSO_CONTROLLER.mainUserName];
                                UIAlertView *alert = [[UIAlertView alloc]
                                                      initWithTitle:@"SmartCampus会員にログイン済みです。"
                                                      message:message
                                                      delegate:self
                                                      cancelButtonTitle:@"キャンセル"
                                                      otherButtonTitles:@"OK", nil];
                                [alert show];
                            }
                            else {
                                [SHARED_SSO_CONTROLLER checkThirdPartyLoginValidation:^(bool b_validated) {
                                    [SVProgressHUD dismiss];
                                    
                                    if (!b_validated) {
                                        [SHARED_SSO_CONTROLLER logoutRequestWithSuccess:nil failure:nil];
                                        
                                        SHARED_SC_MODULE.me = nil;
                                        [SHARED_SC_MODULE saveMe:nil];
                                        [SHARED_SC_MODULE setGuessLogin:NO];
                                        SHARED_SC_MODULE.isUserDidLogged = NO;
                                        SHARED_SC_MODULE.userTokens = nil;
                                        
                                        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
                                        UIViewController *viewController = [storyboard instantiateViewControllerWithIdentifier:@"IntroContainerViewController"];
                                        
                                        [SHARED_SC_MODULE.navigation pushViewController:viewController animated:YES];
                                    }
                                    else if ([self.window.rootViewController isMemberOfClass:[TDCBaseNavigationViewController class]]){
                                        TDCBaseNavigationViewController *navController = (TDCBaseNavigationViewController *)self.window.rootViewController;
                                        TDCBaseTabBarController *tabBarController = navController.viewControllers[0];
                                        TDCFreecopyNaviController *selectedNav = tabBarController.selectedViewController;
                                        if ([selectedNav.viewControllers[0] isMemberOfClass:[TDCCopyViewController class]]) {
                                            [((TDCCopyViewController*)selectedNav.viewControllers[0]) showAdsImage];
                                        }
                                    }
                                }];
                            }
                        }
                        else {
                            [SVProgressHUD dismiss];
                            
                            SHARED_SC_MODULE.me = nil;
                            [SHARED_SC_MODULE saveMe:nil];
                            [SHARED_SC_MODULE setGuessLogin:NO];
                            SHARED_SC_MODULE.isUserDidLogged = NO;
                            SHARED_SC_MODULE.userTokens = nil;
                            
                            [self restoreMainUserLogin];
                        }
                    }];
                }
                else
                    [self restoreMainUserLogin];
            }
        }
    } failure:^(NSError *error) {
        [SCAlertMessage alertWithTitle:nil message:error.localizedDescription error:error];
    }];
}

-(void)presentLoginView {
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    //CPBaseLoginNavigationViewController
    TDCBaseNavigationViewController *baseNav = [storyboard instantiateViewControllerWithIdentifier:@"TDCBaseNavigationViewController"];
    
    SHARED_SC_MODULE.navigation = baseNav;
    APP_DELEGATE.window.rootViewController = baseNav;
    
    UIViewController *viewController = [storyboard instantiateViewControllerWithIdentifier:@"IntroContainerViewController"];
    
    [SHARED_SC_MODULE.navigation pushViewController:viewController animated:YES];
}

-(void)restoreMainUserLogin {
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    TDCBaseNavigationViewController *baseNav = [storyboard instantiateViewControllerWithIdentifier:@"TDCBaseNavigationViewController"];
    
    SHARED_SC_MODULE.navigation = baseNav;
    APP_DELEGATE.window.rootViewController = baseNav;
    
    UIViewController *viewController = [storyboard instantiateViewControllerWithIdentifier:@"TDCSSOLoginRestoreViewController"];
    
    [SHARED_SC_MODULE.navigation pushViewController:viewController animated:YES];
}

- (void)alertView:(UIAlertView*)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    [SVProgressHUD showWithMaskType:SVProgressHUDMaskTypeClear];
    
    if (buttonIndex == 1) {
        //OK
        [SHARED_SSO_CONTROLLER logoutRequestWithSuccess:^(bool success) {
            SHARED_SC_MODULE.me = nil;
            [SHARED_SC_MODULE saveMe:nil];
            [SHARED_SC_MODULE setGuessLogin:NO];
            SHARED_SC_MODULE.isUserDidLogged = NO;
            SHARED_SC_MODULE.userTokens = nil;
            
            SHARED_SC_MODULE.me = [[SCUserData alloc] initWithDictionary:@{@"email": SHARED_SSO_CONTROLLER.mainUserEmail}];
            SHARED_SC_MODULE.userTokens = SHARED_SSO_CONTROLLER.mainUserTokens;
            [SHARED_SC_MODULE saveTypeLogin:SHARED_SSO_CONTROLLER.mainUserLoginType];
            
            [self restoreMainUserLogin];
            
        } failure:^(NSError * error) {
            SHARED_SC_MODULE.me = nil;
            [SHARED_SC_MODULE saveMe:nil];
            [SHARED_SC_MODULE setGuessLogin:NO];
            SHARED_SC_MODULE.isUserDidLogged = NO;
            SHARED_SC_MODULE.userTokens = nil;
            
            SHARED_SC_MODULE.me = [[SCUserData alloc] initWithDictionary:@{@"email": SHARED_SSO_CONTROLLER.mainUserEmail}];
            SHARED_SC_MODULE.userTokens = SHARED_SSO_CONTROLLER.mainUserTokens;
            [SHARED_SC_MODULE saveTypeLogin:SHARED_SSO_CONTROLLER.mainUserLoginType];
            
            [self restoreMainUserLogin];
        }];
    }
    
    SHARED_SSO_CONTROLLER.mainUserLoginType = 0;
    SHARED_SSO_CONTROLLER.mainUserName = nil;
    SHARED_SSO_CONTROLLER.mainUserTokens = nil;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    
//    if (bNeedToCheckIfUpdated) {
//        [self applicationWillEnterForeground:application];
//    }
    
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    // Saves changes in the application's managed object context before the application terminates.
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    
    if ([[url scheme] isEqualToString:SCHEMA_URL]) {
        NSString *query = [url query];
        if (query.length > 0) {
            NSArray *components = [query componentsSeparatedByString:@"&"];
            NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
            for (NSString *component in components) {
                NSArray *subcomponents = [component componentsSeparatedByString:@"="];
                
                NSString *tmp = [[NSString alloc] init];
                if ([subcomponents count] > 2) {
                    for (int i = 1; i < [subcomponents count]; i++) {
                        tmp = [tmp stringByAppendingString:subcomponents[i]];
                    }
                } else {
                    tmp = [subcomponents objectAtIndex:1];
                }
                
                [parameters setObject:[tmp stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
                               forKey:[[subcomponents objectAtIndex:0] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
            }
            
            // Save first run app
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            if (![defaults objectForKey:KEY_FIRST_RUN]){
                [defaults setObject:[NSDate date] forKey:KEY_FIRST_RUN];
            }
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            if ([parameters[@"action"] isEqualToString:@"loign_mail"]) {
                SHARED_SSO_CONTROLLER.bRegistering = true;
                
                UIStoryboard *storyBoard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
                TDCBaseNavigationViewController *base = [storyBoard instantiateViewControllerWithIdentifier:@"TDCBaseNavigationViewController"];
                
                SHARED_SC_MODULE.navigation = base;
                APP_DELEGATE.window.rootViewController = base;
                
                TDCLoginEmailViewController *vc = [storyBoard instantiateViewControllerWithIdentifier:@"TDCLoginEmailViewController"];
                vc.emailString = parameters[@"email"];
                vc.pwdString = parameters[@"password"];
                vc.bHashPass = true;
                
                [[SCModule shareInstanceModule] saveMe:nil];
                [[SCModule shareInstanceModule] setGuessLogin:NO];
                [SCModule shareInstanceModule].isUserDidLogged = YES;
                
                [base pushViewController:vc animated:YES];
                
                base.view.alpha = 0;
                [UIView animateWithDuration:.5f animations:^{
                    base.view.alpha = 1;
                }];
                
            }
            
            if ([parameters[@"action"] isEqualToString:@"open_app"]) {
                SCUserData *user = [SCModule shareInstanceModule].userInfo;
                
                NSError *jsonError;
                NSData *objectData = [parameters[@"user_data"] dataUsingEncoding:NSUTF8StringEncoding];
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:objectData
                                                                     options:NSJSONReadingMutableContainers
                                                                       error:&jsonError];
                SCUserData *newUser = [[SCUserData alloc] initWithDictionary:json];
                
                if (![newUser.appId isEqualToString:user.appId]) {
                    
                    LOGIN_TYPE type = [parameters[@"logged_type"] integerValue];
                    [[SCModule shareInstanceModule] saveTypeLogin:type];
                    
                    // Save info user
                    [[SCModule shareInstanceModule] saveMe:newUser];
                    
                    [self setLoginToRootWindow];
                }
            }
            
            // Open page
            if ([parameters[@"action"] isEqualToString:@"open_page"]) {
                BOOL userNil = [[SCModule shareInstanceModule] isNilUser];
                if (!userNil) {
                    TDCBaseNavigationViewController *navController = (TDCBaseNavigationViewController *)self.window.rootViewController;
                    TDCBaseTabBarController *tabBarController = navController.viewControllers[0];
                    [TDCDeepLink initDeepLinkWithTabBarController:tabBarController andParameter:parameters];
                } else {
                    [self setLoginToRootWindow];
                }
            }
        }
    }
    
    return [[FBSDKApplicationDelegate sharedInstance] application:application
                                                          openURL:url
                                                sourceApplication:sourceApplication
                                                       annotation:annotation];
}

//- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
//    // handler code here
//    
//    return YES;
//}

#pragma mark - Update NavigationBar

-(void)setNavigationBarStyle {
    CGRect navBarFrame = [UINavigationBar appearance].frame;
    
    CGSize imageSize = CGSizeMake(navBarFrame.size.width, navBarFrame.size.height - 2.0f);
    UIColor *fillColor = [UIColor blackColor];
    UIGraphicsBeginImageContextWithOptions(imageSize, YES, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [fillColor setFill];
    CGContextFillRect(context, CGRectMake(0, 0, imageSize.width, imageSize.height - 2.0f));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    
    [[UINavigationBar appearance] setBackgroundImage:image
                                      forBarPosition:UIBarPositionAny
                                          barMetrics:UIBarMetricsDefault];
    
    [[UINavigationBar appearance] setShadowImage:[UIImage new]];
    
    [UINavigationBar appearance].backgroundColor = [UIColor blackColor];
    
    [UINavigationBar appearance].barTintColor = [UIColor blackColor];
    
    [[UIBarButtonItem appearance] setBackButtonTitlePositionAdjustment:UIOffsetMake(0.0f, -60.0f)
                                                         forBarMetrics:UIBarMetricsDefault];
    
    UINavigationBar* appearanceNavigationBar = [UINavigationBar appearance];
    //the appearanceProxy returns NO, so ask the class directly
    if ([[UINavigationBar class] instancesRespondToSelector:@selector(setBackIndicatorImage:)])
    {
        appearanceNavigationBar.backIndicatorImage = [UIImage imageNamed:@"btn_nav_back"];
        appearanceNavigationBar.backIndicatorTransitionMaskImage = [UIImage imageNamed:@"btn_nav_back"];
        //sets back button color
        appearanceNavigationBar.tintColor = COLOR_APP;
    }
}

#pragma mark -

-(void)showAlertForForceUpdate:(NSString*)link {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil
                                                                             message:@"アプリの最新バージョンがあります。"
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK"
                                                       style:UIAlertActionStyleDefault
                                                     handler:^(UIAlertAction * _Nonnull action) {
                                                         [[UIApplication sharedApplication] openURL:[NSURL URLWithString:link]];
                                                     }];
    [alertController addAction:okAction];
    
    [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alertController
                                                                                 animated:true
                                                                               completion:nil];
}

- (void)notifiDidRegisterProfileFinish:(NSNotification*)aNotification
{
    UIStoryboard *storyBoard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    TDCBaseTabBarController *vc = [storyBoard instantiateViewControllerWithIdentifier:@"TDCBaseTabBarController"];
    [[SCModule shareInstanceModule].navigation pushViewController:vc animated:YES];
    [SCModule shareInstanceModule].isUserDidLogged = YES;
}

- (void)updateEmail:(NSNotification*)aNotification
{
//    UIStoryboard *storyBoard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
//    TDCBaseNavigationViewController *base = [storyBoard instantiateViewControllerWithIdentifier:@"TDCLoginNavigationViewController"];
//    [[SCModule shareInstanceModule] saveMe:nil];
//    [[SCModule shareInstanceModule] setGuessLogin:NO];
//    
//    self.window.rootViewController = base;
//    
//    base.view.alpha = 0;
//    [UIView animateWithDuration:.5f animations:^{
//        base.view.alpha = 1;
//    }];
}

- (void)setLoginToRootWindow {
    UIStoryboard *storyBoard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    TDCBaseNavigationViewController *base = [storyBoard instantiateViewControllerWithIdentifier:@"TDCLoginNavigationViewController"];
    TDCLoginViewController *loginVC = [base viewControllers][0];
    self.window.rootViewController = base;
    
    base.view.alpha = 0;
    [UIView animateWithDuration:.35f animations:^{
        base.view.alpha = 1;
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"DidFinishProfileUser" object:nil];
        [loginVC.navigationController setNavigationBarHidden:YES animated:NO];
    }];
}

#pragma mark API
+ (NSDictionary*)paramsWithEmail:(NSString*)email andPassword:(NSString*)password
{
    NSDictionary *p = [SCGenerateKey generateParamEmail:email];
    NSMutableDictionary *params = [p mutableCopy];
    [params setObject:@"7a782d1469105bec062451e7b09b9316" forKey:@"password"];
    [params setObject:[NSNumber numberWithInteger:IS_CANPASS_BUNDLE?CANPASS:TADACOPY] forKey:@"applicaiton_id"];
    [params setObject:@"iphone" forKey:@"agent"];
    [params setObject:[NSNumber numberWithBool:YES] forKey:@"is_hash"];
    
    return params;
}

- (void)requestLoginMailWithEmail:(NSString*)email
                         password:(NSString*)password
                       controller:(UIViewController*)controller {
    // Loading
    [SVProgressHUD showWithMaskType:SVProgressHUDMaskTypeClear];
    
    NSDictionary *params = [AppDelegate paramsWithEmail:email andPassword:password];
    
    [SCAPI requestWithPath:API_LOGIN_EMAIL
                      type:MethodTypePOST
              headerParams:nil
                bodyParams:params
                   success:^(id responseObject) {
                       
                       if (responseObject[@"error"]) {
                           int code = [responseObject[@"error_code"] intValue];
                           [self showMessageWithErrorCode:code message:responseObject[@"error"]];
                           
                           // Dismiss loading
                           [SVProgressHUD dismiss];
                           
                       } else {
                           // Dismiss
                           SCUserData *userInfo = [[SCUserData alloc] initWithDictionary:responseObject[@"user_data"]];
                           
                           if ([SCModule shareInstanceModule].isUserDidLogged) {
                               [SCModule shareInstanceModule].me = userInfo;
                               [SCModule shareInstanceModule].appId = userInfo.appId;
                               [SCModule shareInstanceModule].isGuessUser = NO;
                               [SCModule shareInstanceModule].loginType = LOGIN_TYPE_MAIL;
                           } else {
                               // Save flag in local
                               [[SCModule shareInstanceModule] setGuessLogin:NO];
                               
                               // Save info
                               [[SCAppId sharedAppId] saveAppId:userInfo.appId];
                               
                               // Save type login
                               [[SCModule shareInstanceModule] saveTypeLogin:LOGIN_TYPE_MAIL];
                               
                               [[SCModule shareInstanceModule] saveMe:userInfo];
                           }
                           
                           [[SCModule shareInstanceModule] sendRequestRegisterDevice:^(BOOL success) {
                               if (success) {
                                   
                                   // Save account
                                   //[[SCModule shareInstanceModule] saveAccountWithEmail:email password:password];
                                   
                                   // Swith user
                                   [SCModule shareInstanceModule].isSwitchingGuessUser = NO;
                                   
                                   if ([userInfo isProfile1DataNull]) {
                                       SCRegisterController *vc = [[SCRegisterController alloc] init];
                                       vc.loginType = LOGIN_TYPE_MAIL;
                                       [controller.navigationController pushViewController:vc animated:YES];
                                   } else {
                                       [[NSNotificationCenter defaultCenter] postNotificationName:FINISH_PROFILE2 object:nil];
                                       [controller.navigationController setNavigationBarHidden:YES animated:NO];
                                   }
                               }
                           }];
                       }
                   } failure:^(NSError *error) {
                       [SCAlertMessage alertWithTitle:nil message:REQUEST_FAIL error:error];
                   }];
}

// Show popup error
- (void)showMessageWithErrorCode:(int)code message:(NSString*)message
{
    switch (code) {
        case 1:
            [SCAlertMessage alertWithTitle:nil message:ERROR_CODE_1 error:nil];
            break;
            
        case 2:
            [SCAlertMessage alertWithTitle:nil message:ERROR_CODE_2 error:nil];
            break;
            
        case 3:
            [SCAlertMessage alertWithTitle:nil message:ERROR_CODE_3 error:nil];
            break;
            
        case 4:
            [SCAlertMessage alertWithTitle:nil message:ERROR_CODE_4 error:nil];
            break;
            
        default:
            [SCAlertMessage alertWithTitle:nil message:message error:nil];
            break;
    }
    
}

+(void)registerRemoteNotification {
    NSString *currentVersion = [[UIDevice currentDevice] systemVersion];
    if([currentVersion compare:@"8.0" options:NSNumericSearch] == NSOrderedAscending){
        
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes: (UIRemoteNotificationTypeBadge|
                                                                                UIRemoteNotificationTypeSound|
                                                                                UIRemoteNotificationTypeAlert)];
        
    } else {
        UIUserNotificationType types = UIUserNotificationTypeBadge | UIUserNotificationTypeSound | UIUserNotificationTypeAlert;
        
        UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:types categories:nil];
        
        [[UIApplication sharedApplication] registerForRemoteNotifications];
        [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
    }
}

+(void)unregisterRemoteNotification {
    [[UIApplication sharedApplication] unregisterForRemoteNotifications];
}

@end
