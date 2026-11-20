#import "STSettingsViewController.h"
#import "STCityViewController.h"
#import "STStore.h"
#import "STTheme.h"

@interface STAboutViewController : UIViewController
@end

@interface STStationSpacingViewController : UITableViewController
@property(nonatomic, retain) NSArray *values;
@end

@implementation STSettingsViewController

- (id)init {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) self.title = @"Настройки";
    return self;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    STApplyNavigationTheme(self.navigationController);
    STApplyTableTheme(self.tableView);
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 4; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 2;
    if (section == 1) return 3;
    if (section == 2) return 1;
    return 2;
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"Основные";
    if (section == 1) return @"Карта";
    if (section == 2) return @"Оформление";
    return @"Приложение";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"SettingsCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identifier] autorelease];
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    cell.detailTextLabel.text = nil;
    STApplyCellTheme(cell);
    if (indexPath.section == 0 && indexPath.row == 0) {
        cell.textLabel.text = @"Город";
        cell.detailTextLabel.text = STString([[[STStore sharedStore] selectedCity] objectForKey:@"name"]);
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if (indexPath.section == 0) {
        cell.textLabel.text = @"Обновить данные";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if (indexPath.section == 1 && indexPath.row == 0) {
        cell.textLabel.text = @"Тип карты";
        UISegmentedControl *segments = [[[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@"Схема", @"Спутник", @"Гибрид", nil]] autorelease];
        segments.frame = CGRectMake(0, 0, 205, 30);
        segments.selectedSegmentIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"STMapType"];
        [segments addTarget:self action:@selector(mapTypeChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = segments;
    } else if (indexPath.section == 1) {
        if (indexPath.row == 1) {
            cell.textLabel.text = @"Значки остановок";
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            UISwitch *stationSwitch = [[[UISwitch alloc] initWithFrame:CGRectZero] autorelease];
            stationSwitch.on = STStationIconsEnabled();
            [stationSwitch addTarget:self action:@selector(stationIconsChanged:) forControlEvents:UIControlEventValueChanged];
            stationSwitch.accessibilityLabel = @"Показывать фиолетовые значки остановок";
            cell.accessoryView = stationSwitch;
        } else {
            cell.textLabel.text = @"Разреживание (БЕТА)";
            NSInteger spacing = STStationSpacingMeters();
            cell.detailTextLabel.text = spacing ? [NSString stringWithFormat:@"%ld м", (long)spacing] : @"Все";
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
    } else if (indexPath.section == 2) {
        cell.textLabel.text = @"Тема";
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        UISegmentedControl *theme = [[[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@"iOS 6", @"iOS 7", @"Тёмная", nil]] autorelease];
        theme.frame = CGRectMake(0, 0, 207, 30);
        theme.selectedSegmentIndex = STCurrentThemeStyle();
        [theme addTarget:self action:@selector(themeChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = theme;
    } else if (indexPath.section == 3 && indexPath.row == 0) {
        cell.textLabel.text = @"Очистить кэш";
        unsigned long long bytes = [[STStore sharedStore] cacheSizeBytes];
        cell.detailTextLabel.text = bytes < 1024
            ? [NSString stringWithFormat:@"%llu Б", bytes]
            : (bytes < 1024 * 1024
               ? [NSString stringWithFormat:@"%.0f КБ", (double)bytes / 1024.0]
               : [NSString stringWithFormat:@"%.1f МБ", (double)bytes / (1024.0 * 1024.0)]);
    } else {
        cell.textLabel.text = @"О приложении";
        cell.detailTextLabel.text = @"2.6.143";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return cell;
}

- (void)stationIconsChanged:(UISwitch *)sender {
    STSetStationIconsEnabled(sender.on);
}

- (void)themeChanged:(UISegmentedControl *)sender {
    STSetThemeStyle((STThemeStyle)sender.selectedSegmentIndex);
    STApplyNavigationTheme(self.navigationController);
    STApplyTableTheme(self.tableView);
    [self.tableView reloadData];
}

- (void)mapTypeChanged:(UISegmentedControl *)sender {
    [[NSUserDefaults standardUserDefaults] setInteger:sender.selectedSegmentIndex forKey:@"STMapType"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:STMapTypeDidChangeNotification object:nil];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0 && indexPath.row == 0) {
        [self.navigationController pushViewController:[[[STCityViewController alloc] init] autorelease] animated:YES];
    } else if (indexPath.section == 0 && indexPath.row == 1) {
        self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"Загрузка…" style:UIBarButtonItemStylePlain target:nil action:nil] autorelease];
        [[STStore sharedStore] selectCityCode:[STStore sharedStore].cityCode completion:^(NSError *error) {
            self.navigationItem.rightBarButtonItem = nil;
            if (error) STShowError(self, [error localizedDescription]);
            else [self.tableView reloadData];
        }];
    } else if (indexPath.section == 1 && indexPath.row == 2) {
        [self.navigationController pushViewController:[[[STStationSpacingViewController alloc] init] autorelease] animated:YES];
    } else if (indexPath.section == 3 && indexPath.row == 0) {
        [[STStore sharedStore] clearCache];
        [self.tableView reloadData];
        UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:@"Кэш очищен" message:@"API-ответы и сетевой кэш удалены. Данные будут загружены заново." delegate:nil cancelButtonTitle:@"ОК" otherButtonTitles:nil] autorelease];
        [alert show];
    } else if (indexPath.section == 3 && indexPath.row == 1) {
        [self.navigationController pushViewController:[[[STAboutViewController alloc] init] autorelease] animated:YES];
    }
}

@end

@implementation STStationSpacingViewController

@synthesize values = _values;

- (id)init {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        self.title = @"Остановки (БЕТА)";
        self.values = [NSArray arrayWithObjects:@0, @25, @50, @75, @100, @125, @150, @175, @200, @225, @250, nil];
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    STApplyNavigationTheme(self.navigationController);
    STApplyTableTheme(self.tableView);
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.values.count; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { return @"Минимальное расстояние между значками"; }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return @"БЕТА: близкие остановки объединяются визуально — из каждой группы остаётся один значок. Сами остановки и поиск не удаляются.";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"StationSpacingCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier] autorelease];
    STApplyCellTheme(cell);
    NSInteger value = [[self.values objectAtIndex:indexPath.row] integerValue];
    cell.textLabel.text = value ? [NSString stringWithFormat:@"%ld метров", (long)value] : @"Показывать все";
    cell.accessoryType = value == STStationSpacingMeters() ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    STSetStationSpacingMeters([[self.values objectAtIndex:indexPath.row] integerValue]);
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)dealloc {
    [_values release];
    [super dealloc];
}

@end

@implementation STAboutViewController

- (id)init {
    self = [super init];
    if (self) self.title = @"О приложении";
    return self;
}

- (void)loadView {
    UIScrollView *scroll = [[[UIScrollView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]] autorelease];
    scroll.backgroundColor = STDarkThemeEnabled()
        ? [UIColor colorWithRed:0.055 green:0.06 blue:0.075 alpha:1.0]
        : (STIOS7ThemeEnabled() ? [UIColor colorWithRed:0.94 green:0.94 blue:0.96 alpha:1.0]
                                : [UIColor colorWithWhite:0.95 alpha:1.0]);
    UIImageView *icon = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Icon-72.png"]] autorelease];
    icon.frame = CGRectMake((scroll.bounds.size.width - 72) / 2, 30, 72, 72);
    [scroll addSubview:icon];
    UILabel *title = [[[UILabel alloc] initWithFrame:CGRectMake(20, 118, scroll.bounds.size.width - 40, 32)] autorelease];
    title.backgroundColor = [UIColor clearColor];
    title.textAlignment = NSTextAlignmentCenter;
    title.font = [UIFont boldSystemFontOfSize:22];
    title.textColor = STDarkThemeEnabled() ? [UIColor whiteColor] : [UIColor blackColor];
    title.text = @"Умный транспорт";
    [scroll addSubview:title];
    UILabel *text = [[[UILabel alloc] initWithFrame:CGRectMake(24, 160, scroll.bounds.size.width - 48, 260)] autorelease];
    text.backgroundColor = [UIColor clearColor];
    text.numberOfLines = 0;
    text.textAlignment = NSTextAlignmentCenter;
    text.font = [UIFont systemFontOfSize:15];
    text.textColor = STDarkThemeEnabled() ? [UIColor colorWithWhite:0.78 alpha:1.0] : [UIColor darkTextColor];
    text.text = @"Версия 2.6.143 для iOS 5/6\n\nПрогноз движения городского транспорта, остановки, маршруты и поиск поездок.\n\nКартографические данные: OpenStreetMap. Данные транспорта предоставляются публичным API Bus62.";
    [scroll addSubview:text];
    scroll.contentSize = CGSizeMake(scroll.bounds.size.width, 450);
    self.view = scroll;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    STApplyNavigationTheme(self.navigationController);
}

@end
