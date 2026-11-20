#import "STForecastViewController.h"
#import "STAPIClient.h"
#import "STStore.h"
#import "STTheme.h"

@interface STForecastViewController ()
@property(nonatomic, retain) NSDictionary *station;
@property(nonatomic, retain) NSArray *forecasts;
@property(nonatomic, retain) UIActivityIndicatorView *spinner;
@property(nonatomic, retain) NSTimer *refreshTimer;
@end

@implementation STForecastViewController

@synthesize station = _station;
@synthesize forecasts = _forecasts;
@synthesize spinner = _spinner;
@synthesize refreshTimer = _refreshTimer;

- (id)initWithStation:(NSDictionary *)station {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        self.station = station;
        self.title = STString([station objectForKey:@"name"]);
        self.forecasts = [NSArray array];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.rowHeight = 62.0;
    STApplyTableTheme(self.tableView);
    self.spinner = [[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray] autorelease];
    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithCustomView:self.spinner] autorelease];
    [self updateFavoriteButton];
    [[STStore sharedStore] addRecentStation:STInteger([self.station objectForKey:@"id"])];
    [self refresh];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    STApplyNavigationTheme(self.navigationController);
    STApplyTableTheme(self.tableView);
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:10.0 target:self selector:@selector(refresh) userInfo:nil repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.refreshTimer invalidate];
    self.refreshTimer = nil;
}

- (void)updateFavoriteButton {
    BOOL favorite = [[STStore sharedStore] isFavoriteStation:STInteger([self.station objectForKey:@"id"])];
    UIBarButtonItem *favoriteButton = [[[UIBarButtonItem alloc] initWithTitle:(favorite ? @"★" : @"☆")
                                                                        style:UIBarButtonItemStylePlain
                                                                       target:self action:@selector(toggleFavorite)] autorelease];
    UIBarButtonItem *refreshButton = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                    target:self action:@selector(refresh)] autorelease];
    self.navigationItem.rightBarButtonItems = [NSArray arrayWithObjects:favoriteButton, refreshButton, nil];
}

- (void)toggleFavorite {
    [[STStore sharedStore] toggleFavoriteStation:STInteger([self.station objectForKey:@"id"])];
    [self updateFavoriteButton];
}

- (void)refresh {
    [self.spinner startAnimating];
    NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:
                                [STStore sharedStore].cityCode, @"city",
                                [NSNumber numberWithInteger:STInteger([self.station objectForKey:@"id"])], @"sid", nil];
    [[STAPIClient sharedClient] getPath:@"getStationForecastsAllTransport.php" parameters:parameters completion:^(id object, NSError *error) {
        [self.spinner stopAnimating];
        if ([object isKindOfClass:[NSArray class]]) {
            self.forecasts = [object sortedArrayUsingComparator:^NSComparisonResult(id first, id second) {
                NSInteger a = STInteger([first objectForKey:@"arrt"]);
                NSInteger b = STInteger([second objectForKey:@"arrt"]);
                if (a < b) return NSOrderedAscending;
                if (a > b) return NSOrderedDescending;
                return NSOrderedSame;
            }];
            [self.tableView reloadData];
        } else if (error && self.forecasts.count == 0) {
            STShowError(self, [error localizedDescription]);
        }
    }];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? 1 : MAX((NSInteger)self.forecasts.count, 1);
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return section == 0 ? @"Остановка" : @"Прогноз прибытия";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"ForecastCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier] autorelease];
    STApplyCellTheme(cell);
    cell.textLabel.numberOfLines = 1;
    cell.detailTextLabel.numberOfLines = 2;
    cell.accessoryType = UITableViewCellAccessoryNone;
    if (indexPath.section == 0) {
        cell.textLabel.text = STString([self.station objectForKey:@"name"]);
        cell.detailTextLabel.text = STString([self.station objectForKey:@"description"]);
        cell.imageView.image = [UIImage imageNamed:(STInteger([self.station objectForKey:@"type"]) == 0 ? @"station-bus.png" : @"station-tram.png")];
        return cell;
    }
    if (self.forecasts.count == 0) {
        cell.textLabel.text = @"Нет прогнозов";
        cell.detailTextLabel.text = @"Потяните список или нажмите обновить";
        cell.imageView.image = nil;
        return cell;
    }
    NSDictionary *item = [self.forecasts objectAtIndex:indexPath.row];
    NSString *route = [NSString stringWithFormat:@"%@ №%@", STTransportName(STString([item objectForKey:@"rtype"])), STString([item objectForKey:@"rnum"])];
    NSInteger state = STInteger([item objectForKey:@"state_id"]);
    NSInteger seconds = STInteger([item objectForKey:@"arrt"]);
    NSString *arrival = state == 4 ? @"на конечной" : [NSString stringWithFormat:@"%ld мин", (long)MAX(1, seconds / 60)];
    NSString *where = STString([item objectForKey:@"where"]);
    NSString *plate = STString([item objectForKey:@"gos_num"]);
    NSMutableArray *features = [NSMutableArray array];
    if ([STString([item objectForKey:@"low_floor"]) isEqualToString:@"1"]) [features addObject:@"низкопольный"];
    if ([STString([item objectForKey:@"wifi"]) isEqualToString:@"1"]) [features addObject:@"Wi‑Fi"];
    cell.textLabel.text = [NSString stringWithFormat:@"%@ — %@", route, arrival];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@%@%@", where,
                                 plate.length ? [NSString stringWithFormat:@" · %@", plate] : @"",
                                 features.count ? [NSString stringWithFormat:@" · %@", [features componentsJoinedByString:@", "]] : @""];
    cell.imageView.image = [UIImage imageNamed:@"vehicle.png"];
    cell.accessibilityLabel = [NSString stringWithFormat:@"%@, %@, %@", route, arrival, where];
    return cell;
}

- (void)dealloc {
    [_station release];
    [_forecasts release];
    [_spinner release];
    [_refreshTimer invalidate];
    [_refreshTimer release];
    [super dealloc];
}

@end
