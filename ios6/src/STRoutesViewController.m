#import "STRoutesViewController.h"
#import "STStore.h"
#import "STTheme.h"
#import <QuartzCore/QuartzCore.h>

@interface STRoutesViewController ()
@property(nonatomic, retain) NSArray *sections;
@property(nonatomic, retain) UISearchBar *searchBar;
@end

@implementation STRoutesViewController

@synthesize delegate = _delegate;
@synthesize favoritesOnly = _favoritesOnly;
@synthesize sections = _sections;
@synthesize searchBar = _searchBar;

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
    self.searchBar = [[[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)] autorelease];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"Номер маршрута";
    STApplySearchBarTheme(self.searchBar);
    self.tableView.tableHeaderView = self.searchBar;
    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"★"
                                                                               style:UIBarButtonItemStylePlain
                                                                              target:self action:@selector(saveEnabledAsFavorites)] autorelease];
    self.navigationItem.rightBarButtonItem.accessibilityLabel = @"Сохранить включённые маршруты в избранное";

    UILabel *hint = [[[UILabel alloc] initWithFrame:CGRectMake(12, 0, self.view.bounds.size.width - 24, 58)] autorelease];
    hint.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    hint.backgroundColor = [UIColor clearColor];
    hint.textAlignment = NSTextAlignmentCenter;
    hint.numberOfLines = 2;
    hint.font = [UIFont systemFontOfSize:11.0];
    hint.textColor = [UIColor colorWithWhite:0.48 alpha:1.0];
    hint.text = @"Нажатие — показать/скрыть транспорт.\nУдерживание — показать все линии маршрута.";
    self.tableView.tableFooterView = hint;
    STApplyTableTheme(self.tableView);
    [self rebuildSections];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    STApplyNavigationTheme(self.navigationController);
    STApplyTableTheme(self.tableView);
    STApplySearchBarTheme(self.searchBar);
    UILabel *hint = (UILabel *)self.tableView.tableFooterView;
    hint.textColor = STDarkThemeEnabled() ? [UIColor colorWithWhite:0.68 alpha:1.0] : [UIColor colorWithWhite:0.48 alpha:1.0];
    [self rebuildSections];
}

- (NSInteger)categoryForRoute:(NSDictionary *)route {
    NSString *type = STString([route objectForKey:@"type"]);
    if ([type isEqualToString:@"Т"] || [type isEqualToString:@"Тб"]) return 1;
    if ([type isEqualToString:@"Тр"] || [type isEqualToString:@"Тм"] || [type isEqualToString:@"Мор"]) return 2;
    return 0;
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

- (BOOL)routeMatchesSearch:(NSDictionary *)route {
    NSString *query = self.searchBar.text;
    if (!query.length) return YES;
    NSString *text = [NSString stringWithFormat:@"%@ %@ %@ %@", STString([route objectForKey:@"number"]),
                      STString([route objectForKey:@"name"]), STString([route objectForKey:@"from_station_name"]),
                      STString([route objectForKey:@"to_station_name"])];
    return [text rangeOfString:query options:NSCaseInsensitiveSearch].location != NSNotFound;
}

- (void)rebuildSections {
    NSMutableArray *buses = [NSMutableArray array];
    NSMutableArray *trolleys = [NSMutableArray array];
    NSMutableArray *trams = [NSMutableArray array];
    NSArray *containers[] = { buses, trolleys, trams };
    NSSet *favorites = [NSSet setWithArray:[[STStore sharedStore] favoriteRouteIDs]];
    NSMutableSet *seen = [NSMutableSet set];
    NSArray *sorted = [[STStore sharedStore].routes sortedArrayUsingComparator:^NSComparisonResult(id first, id second) {
        return [STString([first objectForKey:@"number"]) compare:STString([second objectForKey:@"number"]) options:NSNumericSearch];
    }];
    for (NSDictionary *route in sorted) {
        if (![self routeMatchesSearch:route]) continue;
        if (self.favoritesOnly && ![favorites containsObject:[NSNumber numberWithInteger:STInteger([route objectForKey:@"id"])]]) continue;
        NSString *key = [self groupKeyForRoute:route];
        if ([seen containsObject:key]) continue;
        [seen addObject:key];
        [(NSMutableArray *)containers[[self categoryForRoute:route]] addObject:route];
    }
    self.sections = [NSArray arrayWithObjects:buses, trolleys, trams, nil];
    [self.tableView reloadData];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText { [self rebuildSections]; }
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar { [searchBar resignFirstResponder]; }

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 3; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return 1; }

- (NSString *)titleForCategory:(NSInteger)section {
    if (section == 1) return @"Троллейбусы";
    if (section == 2) return @"Трамваи";
    return @"Автобусы";
}

- (NSArray *)allRoutesForCategory:(NSInteger)category {
    NSSet *favorites = [NSSet setWithArray:[[STStore sharedStore] favoriteRouteIDs]];
    return [[STStore sharedStore].routes filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id route, NSDictionary *bindings) {
        if ([self categoryForRoute:route] != category) return NO;
        return !self.favoritesOnly || [favorites containsObject:[NSNumber numberWithInteger:STInteger([route objectForKey:@"id"])]];
    }]];
}

- (BOOL)anyRouteVisibleInRoutes:(NSArray *)routes {
    NSSet *visible = [NSSet setWithArray:[[STStore sharedStore] visibleRouteIDs]];
    for (NSDictionary *route in routes) {
        if ([visible containsObject:[NSNumber numberWithInteger:STInteger([route objectForKey:@"id"])]]) return YES;
    }
    return NO;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIView *header = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 44)] autorelease];
    header.backgroundColor = STDarkThemeEnabled()
        ? [UIColor colorWithRed:0.08 green:0.09 blue:0.11 alpha:0.96]
        : [UIColor colorWithRed:0.91 green:0.92 blue:0.94 alpha:0.96];
    UILabel *label = [[[UILabel alloc] initWithFrame:CGRectMake(12, 0, header.bounds.size.width - 90, 44)] autorelease];
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    label.backgroundColor = [UIColor clearColor];
    label.font = [UIFont boldSystemFontOfSize:16.0];
    label.textColor = STDarkThemeEnabled() ? [UIColor whiteColor] : [UIColor colorWithWhite:0.18 alpha:1.0];
    label.text = [self titleForCategory:section];
    [header addSubview:label];
    UISwitch *typeSwitch = [[[UISwitch alloc] initWithFrame:CGRectZero] autorelease];
    typeSwitch.tag = section;
    typeSwitch.on = [self anyRouteVisibleInRoutes:[self allRoutesForCategory:section]];
    CGRect switchFrame = typeSwitch.frame;
    switchFrame.origin.x = header.bounds.size.width - switchFrame.size.width - 10;
    switchFrame.origin.y = (44 - switchFrame.size.height) / 2.0;
    typeSwitch.frame = switchFrame;
    typeSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [typeSwitch addTarget:self action:@selector(typeSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [header addSubview:typeSwitch];
    return header;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section { return 44.0; }

- (NSInteger)gridColumnsForWidth:(CGFloat)width {
    return MAX(1, (NSInteger)floor((width - 16.0 + 8.0) / 58.0));
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSUInteger count = [[self.sections objectAtIndex:indexPath.section] count];
    if (!count) return 38.0;
    NSInteger columns = [self gridColumnsForWidth:tableView.bounds.size.width];
    NSInteger rows = (NSInteger)((count + columns - 1) / columns);
    return 8.0 + rows * 58.0;
}

- (UIColor *)colorForRoute:(NSDictionary *)route {
    NSInteger category = [self categoryForRoute:route];
    NSString *type = STString([route objectForKey:@"type"]);
    if (category == 1) return [UIColor colorWithRed:0.00 green:0.667 blue:0.741 alpha:1.0];
    if (category == 2) return [UIColor colorWithRed:0.204 green:0.659 blue:0.325 alpha:1.0];
    if ([type isEqualToString:@"М"] || [type isEqualToString:@"Мт"]) return [UIColor colorWithRed:0.988 green:0.694 blue:0.00 alpha:1.0];
    return [UIColor colorWithRed:1.00 green:0.153 blue:0.110 alpha:1.0];
}

- (BOOL)groupIsVisible:(NSDictionary *)representative {
    return [self anyRouteVisibleInRoutes:[self routesInGroup:representative]];
}

- (void)styleRouteButton:(UIButton *)button route:(NSDictionary *)route enabled:(BOOL)enabled {
    button.layer.cornerRadius = 4.0;
    button.layer.borderWidth = 1.0;
    button.layer.borderColor = (enabled ? [UIColor colorWithWhite:0.15 alpha:0.75] : [UIColor colorWithWhite:0.55 alpha:0.8]).CGColor;
    button.backgroundColor = enabled ? [self colorForRoute:route]
        : (STDarkThemeEnabled() ? [UIColor colorWithWhite:0.17 alpha:1.0] : [UIColor whiteColor]);
    [button setTitleColor:(enabled ? [UIColor colorWithWhite:0.06 alpha:1.0]
                                  : (STDarkThemeEnabled() ? [UIColor colorWithWhite:0.72 alpha:1.0] : [UIColor colorWithWhite:0.30 alpha:1.0]))
                 forState:UIControlStateNormal];
    NSString *number = STString([route objectForKey:@"number"]);
    button.titleLabel.font = [UIFont boldSystemFontOfSize:number.length >= 4 ? 12.0 : 17.0];
    [button setTitle:number forState:UIControlStateNormal];
    button.accessibilityLabel = [NSString stringWithFormat:@"Маршрут %@, %@", number, enabled ? @"включён" : @"выключен"];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"RouteGridCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier] autorelease];
    STApplyCellTheme(cell);
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    NSArray *oldSubviews = [[cell.contentView.subviews copy] autorelease];
    for (UIView *subview in oldSubviews) [subview removeFromSuperview];

    NSArray *routes = [self.sections objectAtIndex:indexPath.section];
    if (!routes.count) {
        UILabel *empty = [[[UILabel alloc] initWithFrame:CGRectMake(12, 0, tableView.bounds.size.width - 24, 38)] autorelease];
        empty.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        empty.backgroundColor = [UIColor clearColor];
        empty.textColor = [UIColor colorWithWhite:0.5 alpha:1.0];
        empty.font = [UIFont systemFontOfSize:13.0];
        empty.text = @"Нет маршрутов";
        [cell.contentView addSubview:empty];
        return cell;
    }

    NSInteger columns = [self gridColumnsForWidth:tableView.bounds.size.width];
    CGFloat size = 50.0;
    CGFloat gap = 8.0;
    CGFloat used = columns * size + (columns - 1) * gap;
    CGFloat startX = floor((tableView.bounds.size.width - used) / 2.0);
    NSUInteger index;
    for (index = 0; index < routes.count; index++) {
        NSDictionary *route = [routes objectAtIndex:index];
        NSInteger row = (NSInteger)index / columns;
        NSInteger column = (NSInteger)index % columns;
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.frame = CGRectMake(startX + column * (size + gap), 5.0 + row * (size + gap), size, size);
        button.tag = indexPath.section * 1000 + (NSInteger)index;
        [self styleRouteButton:button route:route enabled:[self groupIsVisible:route]];
        [button addTarget:self action:@selector(routeButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        UILongPressGestureRecognizer *longPress = [[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(routeButtonHeld:)] autorelease];
        longPress.minimumPressDuration = 0.55;
        [button addGestureRecognizer:longPress];
        [cell.contentView addSubview:button];
    }
    return cell;
}

- (NSDictionary *)routeForButtonTag:(NSInteger)tag {
    NSInteger section = tag / 1000;
    NSInteger index = tag % 1000;
    if (section < 0 || section >= (NSInteger)self.sections.count) return nil;
    NSArray *routes = [self.sections objectAtIndex:section];
    return index >= 0 && index < (NSInteger)routes.count ? [routes objectAtIndex:index] : nil;
}

- (void)setRoutes:(NSArray *)routes visible:(BOOL)shouldShow {
    NSMutableArray *visible = [[[STStore sharedStore] visibleRouteIDs] mutableCopy];
    for (NSDictionary *route in routes) {
        NSNumber *identifier = [NSNumber numberWithInteger:STInteger([route objectForKey:@"id"])];
        [visible removeObject:identifier];
        if (shouldShow) [visible addObject:identifier];
    }
    [[STStore sharedStore] setVisibleRouteIDs:visible];
    [visible release];
}

- (void)routeButtonPressed:(UIButton *)button {
    NSDictionary *route = [self routeForButtonTag:button.tag];
    if (!route) return;
    BOOL enable = ![self groupIsVisible:route];
    [self setRoutes:[self routesInGroup:route] visible:enable];
    [self styleRouteButton:button route:route enabled:enable];
    [self.tableView reloadData];
}

- (void)routeButtonHeld:(UILongPressGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateBegan) return;
    UIButton *button = (UIButton *)recognizer.view;
    NSDictionary *route = [self routeForButtonTag:button.tag];
    if (route && [self.delegate respondsToSelector:@selector(routesViewController:selectedRoute:)]) {
        [self.delegate routesViewController:self selectedRoute:route];
        [self.navigationController popToRootViewControllerAnimated:YES];
    }
}

- (void)typeSwitchChanged:(UISwitch *)sender {
    NSArray *routes = [self allRoutesForCategory:sender.tag];
    [self setRoutes:routes visible:sender.on];
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:sender.tag] withRowAnimation:UITableViewRowAnimationFade];
}

- (void)saveEnabledAsFavorites {
    NSArray *visible = [[STStore sharedStore] visibleRouteIDs];
    [[STStore sharedStore] setFavoriteRouteIDs:visible];
    if (self.favoritesOnly) [self rebuildSections];
    NSMutableSet *groups = [NSMutableSet set];
    NSSet *visibleSet = [NSSet setWithArray:visible];
    for (NSDictionary *route in [STStore sharedStore].routes) {
        if ([visibleSet containsObject:[NSNumber numberWithInteger:STInteger([route objectForKey:@"id"])]]) {
            [groups addObject:[self groupKeyForRoute:route]];
        }
    }
    UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:@"Избранное обновлено"
                                                     message:[NSString stringWithFormat:@"Сохранено включённых маршрутов: %lu", (unsigned long)groups.count]
                                                    delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] autorelease];
    [alert show];
}

- (void)dealloc {
    [_sections release];
    [_searchBar release];
    [super dealloc];
}

@end
