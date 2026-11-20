#import "STStationListViewController.h"
#import "STForecastViewController.h"
#import "STStore.h"
#import "STTheme.h"

@interface STStationListViewController ()
@property(nonatomic, assign) STStationListMode mode;
@property(nonatomic, retain) NSArray *items;
@property(nonatomic, retain) UISearchBar *searchBar;
@property(nonatomic, retain) CLLocation *location;
@end

@implementation STStationListViewController

@synthesize selectionHandler = _selectionHandler;
@synthesize mode = _mode;
@synthesize items = _items;
@synthesize searchBar = _searchBar;
@synthesize location = _location;

- (id)initWithMode:(STStationListMode)mode location:(CLLocation *)location {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        self.mode = mode;
        self.location = location;
        if (mode == STStationListModeFavorites) self.title = @"Избранные остановки";
        else if (mode == STStationListModeRecent) self.title = @"Последние просмотренные";
        else if (mode == STStationListModeNearby) self.title = @"Ближайшие остановки";
        else self.title = @"Поиск остановки";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.searchBar = [[[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)] autorelease];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"Название остановки";
    STApplySearchBarTheme(self.searchBar);
    self.tableView.tableHeaderView = self.searchBar;
    STApplyTableTheme(self.tableView);
    [self rebuildItems:@""];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    STApplyNavigationTheme(self.navigationController);
    STApplyTableTheme(self.tableView);
    STApplySearchBarTheme(self.searchBar);
}

- (void)rebuildItems:(NSString *)query {
    STStore *store = [STStore sharedStore];
    NSArray *source = store.stations;
    if (self.mode == STStationListModeFavorites || self.mode == STStationListModeRecent) {
        NSArray *ids = self.mode == STStationListModeFavorites ? [store favoriteStationIDs] : [store recentStationIDs];
        NSMutableArray *selected = [NSMutableArray array];
        for (NSNumber *number in ids) {
            NSDictionary *station = [store stationWithID:[number integerValue]];
            if (station) [selected addObject:station];
        }
        source = selected;
    }
    if (self.mode == STStationListModeNearby) {
        CLLocation *origin = self.location;
        if (!origin) {
            CLLocationCoordinate2D center = [store selectedCityCoordinate];
            origin = [[[CLLocation alloc] initWithLatitude:center.latitude longitude:center.longitude] autorelease];
        }
        source = [source sortedArrayUsingComparator:^NSComparisonResult(id first, id second) {
            CLLocation *a = [[[CLLocation alloc] initWithLatitude:STCoordinateValue([first objectForKey:@"lat0"])
                                                        longitude:STCoordinateValue([first objectForKey:@"lon0"])] autorelease];
            CLLocation *b = [[[CLLocation alloc] initWithLatitude:STCoordinateValue([second objectForKey:@"lat0"])
                                                        longitude:STCoordinateValue([second objectForKey:@"lon0"])] autorelease];
            CLLocationDistance da = [origin distanceFromLocation:a];
            CLLocationDistance db = [origin distanceFromLocation:b];
            return da < db ? NSOrderedAscending : (da > db ? NSOrderedDescending : NSOrderedSame);
        }];
        if (source.count > 30) source = [source subarrayWithRange:NSMakeRange(0, 30)];
    } else if (self.mode == STStationListModeAll) {
        source = [source sortedArrayUsingComparator:^NSComparisonResult(id first, id second) {
            return [STString([first objectForKey:@"name"]) localizedCaseInsensitiveCompare:STString([second objectForKey:@"name"])];
        }];
    }
    if (query.length) {
        NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(id item, NSDictionary *bindings) {
            NSString *text = [NSString stringWithFormat:@"%@ %@", STString([item objectForKey:@"name"]), STString([item objectForKey:@"description"])];
            return [text rangeOfString:query options:NSCaseInsensitiveSearch].location != NSNotFound;
        }];
        source = [source filteredArrayUsingPredicate:predicate];
    }
    self.items = source;
    [self.tableView reloadData];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText { [self rebuildItems:searchText]; }
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar { [searchBar resignFirstResponder]; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.items.count; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"StationCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier] autorelease];
    STApplyCellTheme(cell);
    NSDictionary *station = [self.items objectAtIndex:indexPath.row];
    cell.textLabel.text = STString([station objectForKey:@"name"]);
    cell.detailTextLabel.text = STString([station objectForKey:@"description"]);
    cell.imageView.image = [UIImage imageNamed:(STInteger([station objectForKey:@"type"]) == 0 ? @"station-bus.png" : @"station-tram.png")];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *station = [self.items objectAtIndex:indexPath.row];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.selectionHandler) {
        self.selectionHandler(station);
        [self.navigationController popViewControllerAnimated:YES];
    } else {
        STForecastViewController *controller = [[[STForecastViewController alloc] initWithStation:station] autorelease];
        [self.navigationController pushViewController:controller animated:YES];
    }
}

- (void)dealloc {
    [_selectionHandler release];
    [_items release];
    [_searchBar release];
    [_location release];
    [super dealloc];
}

@end
