#import "STMenuViewController.h"
#import "STStationListViewController.h"
#import "STRoutePlannerViewController.h"
#import "STSettingsViewController.h"
#import "STCityViewController.h"
#import "STStore.h"
#import "STTheme.h"

@interface STMenuViewController ()
@property(nonatomic, assign) id<STRoutesViewControllerDelegate> routeDelegate;
@property(nonatomic, retain) CLLocation *location;
@end

@implementation STMenuViewController

@synthesize routeDelegate = _routeDelegate;
@synthesize location = _location;

- (id)initWithRouteDelegate:(id<STRoutesViewControllerDelegate>)delegate location:(CLLocation *)location {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        self.title = @"Меню";
        self.routeDelegate = delegate;
        self.location = location;
    }
    return self;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 5; }

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    STApplyNavigationTheme(self.navigationController);
    STApplyTableTheme(self.tableView);
    [self.tableView reloadData];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 1;
    if (section == 1) return 2;
    if (section == 2) return 4;
    if (section == 3) return 1;
    return 1;
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 1) return @"Транспорт на карте";
    if (section == 2) return @"Прогноз для остановки";
    if (section == 3) return @"Поездка";
    if (section == 4) return @"Приложение";
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"MenuCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identifier] autorelease];
    STApplyCellTheme(cell);
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.detailTextLabel.text = nil;
    if (indexPath.section == 0) {
        cell.textLabel.text = @"Выбрать город";
        cell.detailTextLabel.text = STString([[[STStore sharedStore] selectedCity] objectForKey:@"name"]);
    } else if (indexPath.section == 1) {
        cell.textLabel.text = indexPath.row == 0 ? @"Все маршруты" : @"Избранные маршруты";
    } else if (indexPath.section == 2) {
        NSArray *names = [NSArray arrayWithObjects:@"Поиск по названию", @"Избранные остановки", @"Последние просмотренные", @"Ближайшие остановки", nil];
        cell.textLabel.text = [names objectAtIndex:indexPath.row];
    } else if (indexPath.section == 3) {
        cell.textLabel.text = @"Проложить маршрут";
    } else {
        NSArray *names = [NSArray arrayWithObjects:@"Настройки", nil];
        cell.textLabel.text = [names objectAtIndex:indexPath.row];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    UIViewController *controller = nil;
    if (indexPath.section == 0) {
        controller = [[[STCityViewController alloc] init] autorelease];
    } else if (indexPath.section == 1) {
        STRoutesViewController *routes = [[[STRoutesViewController alloc] initWithFavoritesOnly:(indexPath.row == 1)] autorelease];
        routes.delegate = self.routeDelegate;
        controller = routes;
    } else if (indexPath.section == 2) {
        STStationListMode modes[] = { STStationListModeAll, STStationListModeFavorites, STStationListModeRecent, STStationListModeNearby };
        controller = [[[STStationListViewController alloc] initWithMode:modes[indexPath.row] location:self.location] autorelease];
    } else if (indexPath.section == 3) {
        controller = [[[STRoutePlannerViewController alloc] init] autorelease];
    } else {
        controller = [[[STSettingsViewController alloc] init] autorelease];
    }
    if (controller) [self.navigationController pushViewController:controller animated:YES];
}

- (void)dealloc {
    [_location release];
    [super dealloc];
}

@end
