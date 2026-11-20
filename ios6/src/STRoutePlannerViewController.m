#import "STRoutePlannerViewController.h"
#import "STStationListViewController.h"
#import "STAPIClient.h"
#import "STStore.h"
#import "STTheme.h"

@interface STTripDetailViewController : UITableViewController
@property(nonatomic, retain) NSDictionary *trip;
- (id)initWithTrip:(NSDictionary *)trip;
@end

@interface STRoutePlannerViewController ()
@property(nonatomic, retain) NSDictionary *fromStation;
@property(nonatomic, retain) NSDictionary *toStation;
@property(nonatomic, retain) NSArray *trips;
@property(nonatomic, retain) UIActivityIndicatorView *spinner;
@end

@implementation STRoutePlannerViewController

@synthesize fromStation = _fromStation;
@synthesize toStation = _toStation;
@synthesize trips = _trips;
@synthesize spinner = _spinner;

- (id)init {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        self.title = @"Проложить маршрут";
        self.trips = [NSArray array];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    STApplyTableTheme(self.tableView);
    self.spinner = [[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray] autorelease];
    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithCustomView:self.spinner] autorelease];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    STApplyNavigationTheme(self.navigationController);
    STApplyTableTheme(self.tableView);
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return self.trips.count ? 3 : 2; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 2;
    if (section == 1) return 1;
    return self.trips.count;
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"Точки маршрута";
    if (section == 2) return @"Варианты поездки";
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"PlannerCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier] autorelease];
    STApplyCellTheme(cell);
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.textLabel.textAlignment = NSTextAlignmentLeft;
    cell.textLabel.textColor = STDarkThemeEnabled() ? [UIColor whiteColor] : [UIColor blackColor];
    if (indexPath.section == 0) {
        NSDictionary *station = indexPath.row == 0 ? self.fromStation : self.toStation;
        cell.textLabel.text = station ? STString([station objectForKey:@"name"]) : (indexPath.row == 0 ? @"Откуда" : @"Куда");
        cell.detailTextLabel.text = station ? STString([station objectForKey:@"description"]) : @"Выберите остановку";
    } else if (indexPath.section == 1) {
        cell.textLabel.text = @"Найти маршрут";
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.textLabel.textColor = STTintColor();
        cell.detailTextLabel.text = nil;
        cell.accessoryType = UITableViewCellAccessoryNone;
    } else {
        NSDictionary *trip = [self.trips objectAtIndex:indexPath.row];
        cell.textLabel.text = STString([trip objectForKey:@"name"]);
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · пересадок: %ld", STString([trip objectForKey:@"duration"]), (long)STInteger([trip objectForKey:@"changes"])];
    }
    return cell;
}

- (void)choosePointAtIndex:(NSInteger)index {
    STStationListViewController *controller = [[[STStationListViewController alloc] initWithMode:STStationListModeAll location:nil] autorelease];
    controller.title = index == 0 ? @"Откуда" : @"Куда";
    controller.selectionHandler = ^(NSDictionary *station) {
        if (index == 0) self.fromStation = station;
        else self.toStation = station;
        [self.tableView reloadData];
    };
    [self.navigationController pushViewController:controller animated:YES];
}

- (NSString *)pointStringForStation:(NSDictionary *)station {
    double lat = STCoordinateValue([station objectForKey:@"lat0"]);
    double lon = STCoordinateValue([station objectForKey:@"lon0"]);
    NSString *point = [NSString stringWithFormat:@"%.6f;%.6f", lat, lon];
    return [point stringByReplacingOccurrencesOfString:@"." withString:@","];
}

- (void)buildRoute {
    if (!self.fromStation || !self.toStation) {
        STShowError(self, @"Выберите начальную и конечную остановки");
        return;
    }
    [self.spinner startAnimating];
    NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:
                                [self pointStringForStation:self.fromStation], @"from",
                                [self pointStringForStation:self.toStation], @"to",
                                [STStore sharedStore].cityCode, @"city",
                                @"json", @"format", nil];
    [[STAPIClient sharedClient] getPath:@"buildRoute.php" parameters:parameters completion:^(id object, NSError *error) {
        [self.spinner stopAnimating];
        NSArray *routes = [object isKindOfClass:[NSDictionary class]] ? [object objectForKey:@"routes"] : nil;
        if ([routes isKindOfClass:[NSArray class]]) {
            self.trips = routes;
            [self.tableView reloadData];
            if (routes.count == 0) STShowError(self, @"Маршруты не найдены");
        } else {
            STShowError(self, error ? [error localizedDescription] : @"Маршруты не найдены");
        }
    }];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0) [self choosePointAtIndex:indexPath.row];
    else if (indexPath.section == 1) [self buildRoute];
    else {
        STTripDetailViewController *detail = [[[STTripDetailViewController alloc] initWithTrip:[self.trips objectAtIndex:indexPath.row]] autorelease];
        [self.navigationController pushViewController:detail animated:YES];
    }
}

- (void)dealloc {
    [_fromStation release];
    [_toStation release];
    [_trips release];
    [_spinner release];
    [super dealloc];
}

@end

@implementation STTripDetailViewController

@synthesize trip = _trip;

- (id)initWithTrip:(NSDictionary *)trip {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        self.trip = trip;
        self.title = STString([trip objectForKey:@"name"]);
    }
    return self;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    STApplyNavigationTheme(self.navigationController);
    STApplyTableTheme(self.tableView);
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 1;
    NSArray *steps = [self.trip objectForKey:@"steps"];
    return [steps isKindOfClass:[NSArray class]] ? steps.count : 0;
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { return section == 0 ? @"Поездка" : @"Этапы"; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"TripStep";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier] autorelease];
    STApplyCellTheme(cell);
    cell.textLabel.numberOfLines = 2;
    cell.detailTextLabel.numberOfLines = 3;
    if (indexPath.section == 0) {
        cell.textLabel.text = STString([self.trip objectForKey:@"name"]);
        cell.detailTextLabel.text = [NSString stringWithFormat:@"Продолжительность: %@\nПересадок: %ld", STString([self.trip objectForKey:@"duration"]), (long)STInteger([self.trip objectForKey:@"changes"])];
    } else {
        NSDictionary *step = [[self.trip objectForKey:@"steps"] objectAtIndex:indexPath.row];
        NSDictionary *start = [step objectForKey:@"start"];
        NSDictionary *end = [step objectForKey:@"end"];
        BOOL walk = STInteger([step objectForKey:@"walk"]) != 0;
        cell.textLabel.text = walk ? @"Пешком" : [NSString stringWithFormat:@"%@ → %@", STString([start objectForKey:@"name"]), STString([end objectForKey:@"name"])];
        NSString *instruction = STStripHTML(STString([step objectForKey:@"html_instructions"]));
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@%@", instruction, STString([step objectForKey:@"duration"]).length ? [NSString stringWithFormat:@" · %@", STString([step objectForKey:@"duration"])] : @""];
    }
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath { return indexPath.section == 0 ? 70.0 : 82.0; }

- (void)dealloc {
    [_trip release];
    [super dealloc];
}

@end
