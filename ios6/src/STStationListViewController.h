#import "STCompatibility.h"

typedef enum {
    STStationListModeAll = 0,
    STStationListModeFavorites,
    STStationListModeRecent,
    STStationListModeNearby
} STStationListMode;

typedef void (^STStationSelection)(NSDictionary *station);

@interface STStationListViewController : UITableViewController <UISearchBarDelegate>

@property(nonatomic, copy) STStationSelection selectionHandler;
- (id)initWithMode:(STStationListMode)mode location:(CLLocation *)location;

@end
