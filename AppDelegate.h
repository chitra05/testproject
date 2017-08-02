//
//  AppDelegate.h
//  Tadacopy
//
//  Created by pvhieuz on 5/12/15.
//  Copyright (c) 2015 com.ac-lab.tadacopy. All rights reserved.
//

#import "SampleGLResourceHandler.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (weak, nonatomic) UITabBarController  *tabBarController;
@property (nonatomic, weak) id<SampleGLResourceHandler> glResourceHandler;

-(void)setNavigationBarStyle;

+(void)registerRemoteNotification;
+(void)unregisterRemoteNotification;

@end

