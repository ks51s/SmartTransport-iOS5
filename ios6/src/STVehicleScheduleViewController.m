#import "STVehicleScheduleViewController.h"
#import "STAPIClient.h"
#import "STForecastViewController.h"
#import "STStore.h"
#import "STTheme.h"

@interface STVehicleScheduleViewController ()
@property(nonatomic, retain) NSDictionary *vehicle;
@property(nonatomic, retain) NSArray *schedule;
@property(nonatomic, retain) NSTimer *refreshTimer;
@property(nonatomic, retain) UIActivityIndicatorView *spinner;
@property(nonatomic, assign) BOOL requestInFlight;
@end

@implementation STVehicleScheduleViewController

@synthesize vehicle = _vehicle;
@synthesize schedule = _schedule;
@synthesize refreshTimer = _refreshTimer;
@synthesize spinner = _spinner;
@synthesize requestInFlight = _requestInFlight;

- (id)initWithVehicle:(NSDictionary *)vehicle {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        self.vehicle = vehicle;
        self.schedule = [NSArray array];
        self.title = [NSString stringWithFormat:@"Маршрут №%@", STString([vehicle objectForKey:@"rnum"])];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.rowHeight = 55.0;
    STApplyTableTheme(self.tableView);
    self.spinner = [[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray] autorelease];
    UIBarButtonItem *refresh = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                              target:self action:@selector(refresh)] autorelease];
    self.navigationItem.rightBarButtonItem = refresh;
    [self refresh];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    STApplyNavigationTheme(self.navigationController);
    STApplyTableTheme(self.tableView);
    [self.refreshTimer invalidate];
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(refresh) userInfo:nil repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.refreshTimer invalidate];
    self.refreshTimer = nil;
}

- (void)refresh {
    if (self.requestInFlight) return;
    NSString *vehicleID = STString([self.vehicle objectForKey:@"id"]);
    if (!vehicleID.length) return;
    self.requestInFlight = YES;
    [self.spinner startAnimating];
    NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:
                                [STStore sharedStore].cityCode, @"city", vehicleID, @"vehid", nil];
    [[STAPIClient sharedClient] getVehiclePath:@"getVehicleForecasts.php" parameters:parameters completion:^(id object, NSError *error) {
        self.requestInFlight = NO;
        [self.spinner stopAnimating];
        if ([object isKindOfClass:[NSArray class]]) {
            self.schedule = [object sortedArrayUsingComparator:^NSComparisonResult(id first, id second) {
                NSInteger a = STInteger([first objectForKey:@"arrt"]);
                NSInteger b = STInteger([second objectForKey:@"arrt"]);
                return a < b ? NSOrderedAscending : (a > b ? NSOrderedDescending : NSOrderedSame);
            }];
            [self.tableView reloadData];
        } else if (error && self.schedule.count == 0) {
            STShowError(self, [error localizedDescription]);
        }
    }];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? 1 : MAX((NSInteger)self.schedule.count, 1);
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? @"Транспорт" : @"Полный прогноз по остановкам";
}

- (NSString *)arrivalTextForSeconds:(NSInteger)seconds {
    if (seconds <= 30) return @"сейчас";
    NSInteger minutes = MAX(1, seconds / 60);
    NSDate *date = [NSDate dateWithTimeIntervalSinceNow:seconds];
    NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
    formatter.dateFormat = @"HH:mm";
    return [NSString stringWithFormat:@"через %ld мин · %@", (long)minutes, [formatter stringFromDate:date]];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"VehicleScheduleCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier] autorelease];
    STApplyCellTheme(cell);
    cell.imageView.image = nil;
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    if (indexPath.section == 0) {
        NSString *destination = STString([self.vehicle objectForKey:@"_destination"]);
        cell.textLabel.text = [NSString stringWithFormat:@"%@ №%@ → %@",
                               STTransportName(STString([self.vehicle objectForKey:@"rtype"])),
                               STString([self.vehicle objectForKey:@"rnum"]), destination];
        NSMutableArray *details = [NSMutableArray array];
        NSString *plate = STString([self.vehicle objectForKey:@"gos_num"]);
        if (plate.length) [details addObject:plate];
        if ([STString([self.vehicle objectForKey:@"low_floor"]) isEqualToString:@"1"]) [details addObject:@"низкопольный"];
        if ([STString([self.vehicle objectForKey:@"wifi"]) isEqualToString:@"1"]) [details addObject:@"Wi‑Fi"];
        cell.detailTextLabel.text = [details componentsJoinedByString:@" · "];
        return cell;
    }
    if (self.schedule.count == 0) {
        cell.textLabel.text = @"Нет данных о следующих остановках";
        cell.detailTextLabel.text = @"Прогноз обновляется каждые 5 секунд";
        return cell;
    }
    NSDictionary *forecast = [self.schedule objectAtIndex:indexPath.row];
    NSDictionary *station = [[STStore sharedStore] stationWithID:STInteger([forecast objectForKey:@"stid"])];
    cell.textLabel.text = STString([station objectForKey:@"name"]);
    cell.detailTextLabel.text = STString([station objectForKey:@"description"]);
    UILabel *arrival = [[[UILabel alloc] initWithFrame:CGRectMake(0, 0, 122, 32)] autorelease];
    arrival.backgroundColor = [UIColor clearColor];
    arrival.textAlignment = NSTextAlignmentRight;
    arrival.font = [UIFont boldSystemFontOfSize:12.0];
    arrival.textColor = STTintColor();
    arrival.text = [self arrivalTextForSeconds:STInteger([forecast objectForKey:@"arrt"])];
    cell.accessoryView = arrival;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section != 1 || self.schedule.count == 0) return;
    NSDictionary *forecast = [self.schedule objectAtIndex:indexPath.row];
    NSDictionary *station = [[STStore sharedStore] stationWithID:STInteger([forecast objectForKey:@"stid"])];
    if (station) {
        STForecastViewController *controller = [[[STForecastViewController alloc] initWithStation:station] autorelease];
        [self.navigationController pushViewController:controller animated:YES];
    }
}

- (void)dealloc {
    [_vehicle release];
    [_schedule release];
    [_refreshTimer invalidate];
    [_refreshTimer release];
    [_spinner release];
    [super dealloc];
}

@end
