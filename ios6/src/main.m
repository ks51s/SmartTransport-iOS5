#import <UIKit/UIKit.h>
#import "STAppDelegate.h"

int main(int argc, char *argv[]) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    int result = UIApplicationMain(argc, argv, nil, NSStringFromClass([STAppDelegate class]));
    [pool drain];
    return result;
}
