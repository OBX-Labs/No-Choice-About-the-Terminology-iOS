//
//  AppDelegate.h
//  Choice
//
//  Created by Christian Gratton on 12-06-18.
//  Copyright (c) 2012 Christian Gratton. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Appirater.h"

@class OKPoEMM;
@class EAGLView;

@interface AppDelegate : UIResponder <UIApplicationDelegate, AppiraterDelegate>

@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) OKPoEMM *poemm;
@property (nonatomic, strong) EAGLView *eaglView;

- (void) setDefaultValues;
- (void) promptPerformancePassword;
- (void) loadOKPoEMMInFrame:(CGRect)frame;
- (void) manageAppirater;

@end
