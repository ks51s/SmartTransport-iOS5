#import "STCompatibility.h"

@class STRoutesViewController;

@protocol STRoutesViewControllerDelegate <NSObject>
- (void)routesViewController:(STRoutesViewController *)controller selectedRoute:(NSDictionary *)route;
- (void)routesViewControllerShowAllRoutes:(STRoutesViewController *)controller;
@end

@interface STRoutesViewController : UITableViewController <UISearchBarDelegate>

@property(nonatomic, assign) id<STRoutesViewControllerDelegate> delegate;
@property(nonatomic, assign) BOOL favoritesOnly;

- (id)initWithFavoritesOnly:(BOOL)favoritesOnly;

@end
