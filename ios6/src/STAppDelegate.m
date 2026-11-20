#import "STAppDelegate.h"
#import "STMapViewController.h"
#import "STTheme.h"

@implementation STAppDelegate

@synthesize window = _window;
@synthesize navigationController = _navigationController;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
    STMapViewController *map = [[[STMapViewController alloc] init] autorelease];
    self.navigationController = [[[UINavigationController alloc] initWithRootViewController:map] autorelease];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyTheme) name:STThemeDidChangeNotification object:nil];
    [self applyTheme];
    self.window.rootViewController = self.navigationController;
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applyTheme {
    STApplyNavigationTheme(self.navigationController);
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_navigationController release];
    [_window release];
    [super dealloc];
}

@end
