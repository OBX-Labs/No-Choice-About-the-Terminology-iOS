//
//  AppDelegate.m
//  Choice
//
//  Created by Christian Gratton on 12-06-18.
//  Copyright (c) 2012 Christian Gratton. All rights reserved.
//

#import "AppDelegate.h"

#import "EAGLView.h"
#import "OKPoEMM.h"
#import "OKPreloader.h"
#import "OKTextManager.h"
#import "OKAppProperties.h"
#import "OKPoEMMProperties.h"
#import "OKInfoViewProperties.h"
#import "Appirater.h"

#define IS_IPAD_2 (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) // Or more
#define IS_IPHONE_5 (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone && [[UIScreen mainScreen] bounds].size.height == 568.0f)
#define SHOULD_MULTISAMPLE (IS_IPAD_2 || IS_IPHONE_5)

@implementation AppDelegate
@synthesize window, poemm, eaglView;

- (BOOL) application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    if(![[NSUserDefaults standardUserDefaults] objectForKey:@"fLaunch"])
        [self setDefaultValues];
        
    //Seed randomizer
    srandom(time(NULL));
    
    //Device won't sleep
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
        
    //Init Window
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    // Get Screen Bounds
    CGRect sBounds = [[UIScreen mainScreen] bounds];
    CGRect sFrame = CGRectMake(sBounds.origin.x, sBounds.origin.y, sBounds.size.width, sBounds.size.height); // Invert height and width to componsate for portrait launch (these values will be set to determine behaviors/dimensions in EAGLView)
    
    // Set app properties
    [OKAppProperties initWithContentsOfFile:[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"OKAppProperties.plist"] andOptions:launchOptions];
    [OKPoEMMProperties initWithContentsOfFile:[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"OKPoEMMProperties.plist"]];
        
    // Load texts
    BOOL canLoad = YES;
    // Get the id of the last text the user read
    NSString *textKey = [[NSUserDefaults standardUserDefaults] stringForKey:Text];
    
    NSString *appName = [OKAppProperties objectForKey:@"Name"];
    NSString *master = [NSString stringWithFormat:@"net.obxlabs.%@.jlewis.%@", appName, appName];
    if(textKey != nil)
    {
        //save default key, just in case
        NSString* defaultTextKey = [[OKTextManager sharedInstance] getDefaultPackage];
        
        // Fixes the bug where net.obxlabs.Know.jlewis.Know is replaced by net.obxlabs.Know.jlewis.67 when list is downloaded
        // but no poem is selected. This finds the default poem and returns the right key.
        if([textKey isEqualToString:master])
            textKey = [[OKTextManager sharedInstance] getDefaultPackage];
        
        //load the text
        if (![[OKTextManager sharedInstance] loadTextFromPackage:textKey atIndex:0])
        {
            // try loading custom text
            if(![[OKTextManager sharedInstance] loadCustomTextFromPackage:textKey])
            {
                if(![[OKTextManager sharedInstance] loadTextFromPackage:defaultTextKey atIndex:0])
                {
                    NSLog(@"Error: could not load any text for package %@ and default package %@. Clearing cache and starting from new.", textKey, defaultTextKey);
                    
                    // Deletes existing file (last hope)
                    [OKTextManager clearCache];
                    
                    // Load new
                    if(![[OKTextManager sharedInstance] loadTextFromPackage:@"net.obxlabs.Choice.jlewis.Choice" atIndex:0])
                    {
                        // Epic fail
                        NSLog(@"Error: Epic fail.");
                        canLoad = NO;
                    }
                }
            }
        }
    }
    else
    {
        // Set default text

        if(![[OKTextManager sharedInstance] loadTextFromPackage:master atIndex:0])
        {
            NSLog(@"Error: could not load default package. Probably missing some objects (fonts).");
        }
    }
    
    OKPreloader *preloader = [[OKPreloader alloc] initWithFrame:sFrame forApp:self loadOnAppear:canLoad];
    
    if(!canLoad)
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"System Error" message:@"It would appear that all app files were corrupted. Please delete and re-install the app and try again." delegate:self cancelButtonTitle:@"Dismiss" otherButtonTitles:nil];
        [alert show];
    }
    
    // Add to window
    [self.window setRootViewController:preloader];
    [self.window makeKeyAndVisible];
            
    return YES;
}

- (void) setDefaultValues
{
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"exhibition_preference"];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"performance_preference"];
        
    /* There seems to be an issue with the Bundle Version being 1.0.4 instead of 1.1.4 so I set the default value instead of getting the current one
     [[NSUserDefaults standardUserDefaults] setValue:[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"] forKey:@"version_preference"];
     */
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"fLaunch"];
    
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void) loadOKPoEMMInFrame:(CGRect)frame
{
    // Initialize EAGLView (OpenGL)
    eaglView = [[EAGLView alloc] initWithFrame:frame multisampling:SHOULD_MULTISAMPLE andSamples:2];
    
    // Initilaize OKPoEMM (EAGLView, OKInfoView, OKRegistration... wrapper)
    self.poemm = [[OKPoEMM alloc] initWithFrame:frame EAGLView:eaglView isExhibition:[[NSUserDefaults standardUserDefaults] boolForKey:@"exhibition_preference"]];
    
    //Start EAGLView animation
    if(eaglView) [eaglView startAnimation];
    
    [self.window setRootViewController:self.poemm];
    
    // Asked for performance version
    if([[NSUserDefaults standardUserDefaults] boolForKey:@"performance_preference"]) {
        [self.poemm promptForPerformance];
    } else {
        // If ever performance was disabled, make sure we leave the current state of exhibition
        [self.poemm setisExhibition:[[NSUserDefaults standardUserDefaults] boolForKey:@"exhibition_preference"]];
        
        [eaglView setIsPerformance:NO];
        
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"isPerformance"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }

    //Appirater after eaglview is started and a few seconds after to let everything get in motion
    [self performSelector:@selector(manageAppirater) withObject:nil afterDelay:10.0f];
}

- (void)applicationWillResignActive:(UIApplication *)application
{    
    [eaglView stopAnimation];
    
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    [eaglView startAnimation];
    //[self.poemm setisExhibition:[[NSUserDefaults standardUserDefaults] boolForKey:@"exhibition_preference"]];
    
    // Asked for performance version
    if([[NSUserDefaults standardUserDefaults] boolForKey:@"performance_preference"]) {
        [self.poemm promptForPerformance];
    } else {
        // If ever performance was disabled, make sure we leave the current state of exhibition
        [self.poemm setisExhibition:[[NSUserDefaults standardUserDefaults] boolForKey:@"exhibition_preference"]];
        
        [eaglView setIsPerformance:NO];
        
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"isPerformance"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }

    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    [eaglView stopAnimation];
    //device can sleep (since we leave)
	[[UIApplication sharedApplication] setIdleTimerDisabled:NO];
}

#pragma mark - Appirater

- (void) manageAppirater
{
    [Appirater appLaunched:YES];
    [Appirater setDelegate:self];
    [Appirater setLeavesAppToRate:YES]; // Just too hard on the memory
    [Appirater setAppId:@"475338554"];
    [Appirater setDaysUntilPrompt:5];
    [Appirater setUsesUntilPrompt:5];
}

-(void)appiraterDidDisplayAlert:(Appirater *)appirater
{
    [eaglView stopAnimation];
}

-(void)appiraterDidDeclineToRate:(Appirater *)appirater
{
    [eaglView startAnimation];
}

-(void)appiraterDidOptToRate:(Appirater *)appirater
{
    [eaglView stopAnimation];
}

-(void)appiraterDidOptToRemindLater:(Appirater *)appirater
{
    [eaglView startAnimation];
}

-(void)appiraterWillPresentModalView:(Appirater *)appirater animated:(BOOL)animated
{
    [eaglView stopAnimation];
}

-(void)appiraterDidDismissModalView:(Appirater *)appirater animated:(BOOL)animated
{
    [eaglView startAnimation];
}


@end
