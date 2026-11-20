#import "STCompatibility.h"
#import "STRoutesViewController.h"

@interface STMenuViewController : UITableViewController

- (id)initWithRouteDelegate:(id<STRoutesViewControllerDelegate>)delegate location:(CLLocation *)location;

@end
