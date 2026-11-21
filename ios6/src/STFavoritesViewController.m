#import "STFavoritesViewController.h"
#import "STForecastViewController.h"
#import "STStore.h"
#import "STTheme.h"

@interface STFavoritesViewController ()
@property(nonatomic, assign) id<STRoutesViewControllerDelegate> routeDelegate;
@property(nonatomic, retain) NSArray *routes;
@property(nonatomic, retain) NSArray *stations;
@end

@implementation STFavoritesViewController

@synthesize routeDelegate = _routeDelegate;
@synthesize routes = _routes;
@synthesize stations = _stations;

- (id)initWithRouteDelegate:(id<STRoutesViewControllerDelegate>)delegate {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        self.title = @"Избранное";
        self.routeDelegate = delegate;
    }
    return self;
}

- (void)reloadFavorites {
    STStore *store = [STStore sharedStore];
    NSSet *favoriteRouteIDs = [NSSet setWithArray:[store favoriteRouteIDs]];
    NSMutableSet *seen = [NSMutableSet set];
    NSMutableArray *routes = [NSMutableArray array];
    for (NSDictionary *route in store.routes) {
        NSNumber *identifier = [NSNumber numberWithInteger:STInteger([route objectForKey:@"id"])];
        if (![favoriteRouteIDs containsObject:identifier]) continue;
        NSString *key = [NSString stringWithFormat:@"%@|%@", STString([route objectForKey:@"type"]), STString([route objectForKey:@"number"])];
        if (![seen containsObject:key]) {
            [seen addObject:key];
            [routes addObject:route];
        }
    }
    self.routes = [routes sortedArrayUsingComparator:^NSComparisonResult(id first, id second) {
        return [STString([first objectForKey:@"number"]) compare:STString([second objectForKey:@"number"]) options:NSNumericSearch];
    }];
    NSMutableArray *stations = [NSMutableArray array];
    for (NSNumber *identifier in [store favoriteStationIDs]) {
        NSDictionary *station = [store stationWithID:[identifier integerValue]];
        if (station) [stations addObject:station];
    }
    self.stations = stations;
    [self.tableView reloadData];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    STApplyNavigationTheme(self.navigationController);
    STApplyTableTheme(self.tableView);
    [self reloadFavorites];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSUInteger count = section == 0 ? self.routes.count : self.stations.count;
    return MAX((NSUInteger)1, count);
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? @"Маршруты" : @"Остановки";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"FavoriteCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier] autorelease];
    STApplyCellTheme(cell);
    cell.imageView.image = nil;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    NSArray *items = indexPath.section == 0 ? self.routes : self.stations;
    if (!items.count) {
        cell.textLabel.text = indexPath.section == 0 ? @"Нет избранных маршрутов" : @"Нет избранных остановок";
        cell.detailTextLabel.text = nil;
        cell.accessoryType = UITableViewCellAccessoryNone;
        return cell;
    }
    NSDictionary *item = [items objectAtIndex:indexPath.row];
    if (indexPath.section == 0) {
        cell.textLabel.text = [NSString stringWithFormat:@"%@ №%@", STTransportName(STString([item objectForKey:@"type"])), STString([item objectForKey:@"number"])];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ ↔ %@", STString([item objectForKey:@"from_station_name"]), STString([item objectForKey:@"to_station_name"])];
    } else {
        cell.textLabel.text = STString([item objectForKey:@"name"]);
        cell.detailTextLabel.text = STString([item objectForKey:@"description"]);
        cell.imageView.image = [UIImage imageNamed:(STInteger([item objectForKey:@"type"]) == 0 ? @"station-bus.png" : @"station-tram.png")];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSArray *items = indexPath.section == 0 ? self.routes : self.stations;
    if (!items.count) return;
    NSDictionary *item = [items objectAtIndex:indexPath.row];
    if (indexPath.section == 0 && [self.routeDelegate respondsToSelector:@selector(routesViewController:selectedRoute:)]) {
        [self.routeDelegate routesViewController:nil selectedRoute:item];
        [self.navigationController popToRootViewControllerAnimated:YES];
    } else if (indexPath.section == 1) {
        [self.navigationController pushViewController:[[[STForecastViewController alloc] initWithStation:item] autorelease] animated:YES];
    }
}

- (void)dealloc {
    [_routes release];
    [_stations release];
    [super dealloc];
}

@end
