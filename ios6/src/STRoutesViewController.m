#import "STRoutesViewController.h"
#import "STStore.h"
#import "STTheme.h"

@interface STRoutesViewController ()
@property(nonatomic, retain) NSArray *items;
@property(nonatomic, retain) UISearchBar *searchBar;
@property(nonatomic, retain) UISegmentedControl *tabs;
@end

@implementation STRoutesViewController

@synthesize delegate = _delegate;
@synthesize favoritesOnly = _favoritesOnly;
@synthesize items = _items;
@synthesize searchBar = _searchBar;
@synthesize tabs = _tabs;

- (id)initWithFavoritesOnly:(BOOL)favoritesOnly {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        self.favoritesOnly = favoritesOnly;
        self.title = favoritesOnly ? @"Избранные маршруты" : @"Маршруты";
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    UIView *header = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 88)] autorelease];
    header.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.tabs = [[[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@"Маршруты", @"Транспорт на карте", nil]] autorelease];
    self.tabs.frame = CGRectMake(8, 5, header.bounds.size.width - 16, 31);
    self.tabs.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.tabs.selectedSegmentIndex = 0;
    [self.tabs addTarget:self action:@selector(tabChanged:) forControlEvents:UIControlEventValueChanged];
    [header addSubview:self.tabs];

    self.searchBar = [[[UISearchBar alloc] initWithFrame:CGRectMake(0, 40, header.bounds.size.width, 44)] autorelease];
    self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"Номер или направление";
    STApplySearchBarTheme(self.searchBar);
    [header addSubview:self.searchBar];
    self.tableView.tableHeaderView = header;
    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"Все"
                                                                               style:UIBarButtonItemStylePlain
                                                                              target:self action:@selector(showAllRoutes)] autorelease];
    self.navigationItem.rightBarButtonItem.accessibilityLabel = @"Вернуть все маршруты на карту";
    STApplyTableTheme(self.tableView);
    [self filter:@""];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    STApplyNavigationTheme(self.navigationController);
    STApplyTableTheme(self.tableView);
    STApplySearchBarTheme(self.searchBar);
    [self filter:self.searchBar.text ?: @""];
}

- (NSString *)groupKeyForRoute:(NSDictionary *)route {
    return [NSString stringWithFormat:@"%@|%@", STString([route objectForKey:@"type"]), STString([route objectForKey:@"number"])];
}

- (NSArray *)routesInGroup:(NSDictionary *)representative {
    NSString *key = [self groupKeyForRoute:representative];
    return [[STStore sharedStore].routes filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id route, NSDictionary *bindings) {
        return [[self groupKeyForRoute:route] isEqualToString:key];
    }]];
}

- (void)filter:(NSString *)query {
    STStore *store = [STStore sharedStore];
    NSArray *source = store.routes;
    if (self.favoritesOnly) {
        NSArray *favorites = [store favoriteRouteIDs];
        source = [source filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id route, NSDictionary *bindings) {
            return [favorites containsObject:[NSNumber numberWithInteger:STInteger([route objectForKey:@"id"])]];
        }]];
    }
    if (query.length) {
        source = [source filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id route, NSDictionary *bindings) {
            NSString *text = [NSString stringWithFormat:@"%@ %@ %@ %@", STString([route objectForKey:@"number"]),
                              STString([route objectForKey:@"name"]), STString([route objectForKey:@"from_station_name"]),
                              STString([route objectForKey:@"to_station_name"])];
            return [text rangeOfString:query options:NSCaseInsensitiveSearch].location != NSNotFound;
        }]];
    }
    source = [source sortedArrayUsingComparator:^NSComparisonResult(id first, id second) {
        NSComparisonResult numeric = [STString([first objectForKey:@"number"]) compare:STString([second objectForKey:@"number"]) options:NSNumericSearch];
        if (numeric != NSOrderedSame) return numeric;
        return [STString([first objectForKey:@"type"]) localizedCaseInsensitiveCompare:STString([second objectForKey:@"type"])];
    }];
    NSMutableArray *grouped = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    for (NSDictionary *route in source) {
        NSString *key = [self groupKeyForRoute:route];
        if (![seen containsObject:key]) {
            [seen addObject:key];
            [grouped addObject:route];
        }
    }
    self.items = grouped;
    [self.tableView reloadData];
}

- (void)tabChanged:(UISegmentedControl *)sender {
    self.title = sender.selectedSegmentIndex == 0
        ? (self.favoritesOnly ? @"Избранные маршруты" : @"Маршруты")
        : @"Транспорт на карте";
    [self.tableView reloadData];
}

- (void)showAllRoutes {
    [[STStore sharedStore] showAllRoutes];
    if ([self.delegate respondsToSelector:@selector(routesViewControllerShowAllRoutes:)]) {
        [self.delegate routesViewControllerShowAllRoutes:self];
    }
    [self.navigationController popToRootViewControllerAnimated:YES];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText { [self filter:searchText]; }
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar { [searchBar resignFirstResponder]; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.items.count; }

- (BOOL)groupIsFavorite:(NSArray *)group {
    for (NSDictionary *route in group) {
        if ([[STStore sharedStore] isFavoriteRoute:STInteger([route objectForKey:@"id"])]) return YES;
    }
    return NO;
}

- (BOOL)groupIsVisible:(NSArray *)group {
    NSSet *visible = [NSSet setWithArray:[[STStore sharedStore] visibleRouteIDs]];
    for (NSDictionary *route in group) {
        if ([visible containsObject:[NSNumber numberWithInteger:STInteger([route objectForKey:@"id"])]] ) return YES;
    }
    return NO;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"RouteCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier] autorelease];
    STApplyCellTheme(cell);
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    NSDictionary *route = [self.items objectAtIndex:indexPath.row];
    NSArray *group = [self routesInGroup:route];
    cell.textLabel.text = [NSString stringWithFormat:@"%@ №%@", STTransportName(STString([route objectForKey:@"type"])), STString([route objectForKey:@"number"])];
    NSString *from = STString([route objectForKey:@"from_station_name"]);
    NSString *to = STString([route objectForKey:@"to_station_name"]);
    if (!from.length) from = STString([[[STStore sharedStore] stationWithID:STInteger([route objectForKey:@"from_station_id"])] objectForKey:@"name"]);
    if (!to.length) to = STString([[[STStore sharedStore] stationWithID:STInteger([route objectForKey:@"to_station_id"])] objectForKey:@"name"]);
    if (self.tabs.selectedSegmentIndex == 0) {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ ↔ %@ · направлений: %lu", from, to, (unsigned long)group.count];
        UIButton *star = [UIButton buttonWithType:UIButtonTypeCustom];
        star.frame = CGRectMake(0, 0, 44, 40);
        [star setTitle:([self groupIsFavorite:group] ? @"★" : @"☆") forState:UIControlStateNormal];
        [star setTitleColor:STTintColor() forState:UIControlStateNormal];
        star.titleLabel.font = [UIFont systemFontOfSize:26];
        star.tag = indexPath.row;
        [star addTarget:self action:@selector(toggleFavorite:) forControlEvents:UIControlEventTouchUpInside];
        cell.accessoryView = star;
    } else {
        BOOL visible = [self groupIsVisible:group];
        cell.detailTextLabel.text = visible ? @"Транспорт показывается на карте" : @"Транспорт скрыт";
        cell.accessoryType = visible ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    }
    return cell;
}

- (void)toggleFavorite:(UIButton *)button {
    if (button.tag >= (NSInteger)self.items.count) return;
    NSArray *group = [self routesInGroup:[self.items objectAtIndex:button.tag]];
    BOOL remove = [self groupIsFavorite:group];
    for (NSDictionary *route in group) {
        NSInteger identifier = STInteger([route objectForKey:@"id"]);
        BOOL favorite = [[STStore sharedStore] isFavoriteRoute:identifier];
        if ((remove && favorite) || (!remove && !favorite)) [[STStore sharedStore] toggleFavoriteRoute:identifier];
    }
    [self filter:self.searchBar.text ?: @""];
}

- (void)toggleVisibleGroup:(NSArray *)group {
    NSMutableArray *visible = [[[STStore sharedStore] visibleRouteIDs] mutableCopy];
    BOOL remove = [self groupIsVisible:group];
    for (NSDictionary *route in group) {
        NSNumber *identifier = [NSNumber numberWithInteger:STInteger([route objectForKey:@"id"])] ;
        [visible removeObject:identifier];
        if (!remove) [visible addObject:identifier];
    }
    [[STStore sharedStore] setVisibleRouteIDs:visible];
    [visible release];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *route = [self.items objectAtIndex:indexPath.row];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.tabs.selectedSegmentIndex == 1) {
        [self toggleVisibleGroup:[self routesInGroup:route]];
        [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if ([self.delegate respondsToSelector:@selector(routesViewController:selectedRoute:)]) {
        [self.delegate routesViewController:self selectedRoute:route];
        [self.navigationController popToRootViewControllerAnimated:YES];
    }
}

- (void)dealloc {
    [_items release];
    [_searchBar release];
    [_tabs release];
    [super dealloc];
}

@end
