#import "STMapViewController.h"
#import "STAnnotation.h"
#import "STForecastViewController.h"
#import "STFavoritesViewController.h"
#import "STStationListViewController.h"
#import "STMenuViewController.h"
#import "STSettingsViewController.h"
#import "STAPIClient.h"
#import "STStore.h"
#import "STTheme.h"
#import "STDarkMapOverlay.h"
#import "STVehicleAnnotationView.h"
#import "STVehicleScheduleViewController.h"
#import <QuartzCore/QuartzCore.h>
#import <float.h>

@interface STMapViewController ()
@property(nonatomic, retain) MKMapView *mapView;
@property(nonatomic, retain) NSMutableArray *stationAnnotations;
@property(nonatomic, retain) NSMutableArray *vehicleAnnotations;
@property(nonatomic, retain) NSMutableDictionary *vehicleAnnotationsByID;
@property(nonatomic, retain) NSMutableArray *routeOverlays;
@property(nonatomic, retain) STDarkMapOverlay *darkMapOverlay;
@property(nonatomic, retain) NSArray *currentRoutes;
@property(nonatomic, assign) NSInteger routeLoadGeneration;
@property(nonatomic, retain) CLLocationManager *locationManager;
@property(nonatomic, retain) CLLocation *currentLocation;
@property(nonatomic, retain) UILabel *statusLabel;
@property(nonatomic, retain) NSTimer *vehicleTimer;
@property(nonatomic, retain) UIButton *stationToggleButton;
@property(nonatomic, retain) UIBarButtonItem *vehicleFlagsButton;
@property(nonatomic, retain) UIView *bottomTabBar;
@property(nonatomic, retain) NSArray *bottomTabButtons;
@property(nonatomic, retain) UIButton *routeCloseButton;
@property(nonatomic, assign) NSInteger vehicleAnimationKey;
@property(nonatomic, assign) NSInteger vehicleGeneration;
@property(nonatomic, assign) BOOL vehicleRequestInFlight;
@property(nonatomic, assign) BOOL mapIsVisible;
@property(nonatomic, assign) BOOL snapNextVehicleUpdate;
@property(nonatomic, assign) NSTimeInterval lastVehicleUpdateAt;
@end

@implementation STMapViewController

@synthesize mapView = _mapView;
@synthesize stationAnnotations = _stationAnnotations;
@synthesize vehicleAnnotations = _vehicleAnnotations;
@synthesize vehicleAnnotationsByID = _vehicleAnnotationsByID;
@synthesize routeOverlays = _routeOverlays;
@synthesize darkMapOverlay = _darkMapOverlay;
@synthesize currentRoutes = _currentRoutes;
@synthesize routeLoadGeneration = _routeLoadGeneration;
@synthesize locationManager = _locationManager;
@synthesize currentLocation = _currentLocation;
@synthesize statusLabel = _statusLabel;
@synthesize vehicleTimer = _vehicleTimer;
@synthesize stationToggleButton = _stationToggleButton;
@synthesize vehicleFlagsButton = _vehicleFlagsButton;
@synthesize bottomTabBar = _bottomTabBar;
@synthesize bottomTabButtons = _bottomTabButtons;
@synthesize routeCloseButton = _routeCloseButton;
@synthesize vehicleAnimationKey = _vehicleAnimationKey;
@synthesize vehicleGeneration = _vehicleGeneration;
@synthesize vehicleRequestInFlight = _vehicleRequestInFlight;
@synthesize mapIsVisible = _mapIsVisible;
@synthesize snapNextVehicleUpdate = _snapNextVehicleUpdate;
@synthesize lastVehicleUpdateAt = _lastVehicleUpdateAt;

- (id)init {
    self = [super init];
    if (self) {
        self.title = @"Умный транспорт";
        self.stationAnnotations = [NSMutableArray array];
        self.vehicleAnnotations = [NSMutableArray array];
        self.vehicleAnnotationsByID = [NSMutableDictionary dictionary];
        self.routeOverlays = [NSMutableArray array];
    }
    return self;
}

- (UIButton *)controlButtonWithTitle:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [button setTitle:title forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    button.accessibilityLabel = title;
    [self styleMapControl:button];
    return button;
}

- (void)styleMapControl:(UIButton *)button {
    if (button.tag == 700) {
        button.backgroundColor = [UIColor clearColor];
        button.layer.borderWidth = 0.0;
        button.layer.shadowOpacity = 0.0;
        return;
    }
    if (STDarkThemeEnabled()) {
        button.backgroundColor = [UIColor colorWithRed:0.08 green:0.09 blue:0.11 alpha:0.91];
        button.layer.cornerRadius = 5.0;
        button.layer.borderColor = [UIColor colorWithWhite:0.32 alpha:1.0].CGColor;
        button.layer.borderWidth = 1.0;
        button.layer.shadowOpacity = 0.0;
        [button setTitleColor:[UIColor colorWithRed:0.28 green:0.64 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
    } else if (STIOS7ThemeEnabled()) {
        button.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.94];
        button.layer.cornerRadius = 4.0;
        button.layer.borderWidth = 0.0;
        button.layer.shadowColor = [UIColor blackColor].CGColor;
        button.layer.shadowOpacity = 0.18;
        button.layer.shadowRadius = 2.0;
        button.layer.shadowOffset = CGSizeMake(0, 1);
        [button setTitleColor:STTintColor() forState:UIControlStateNormal];
    } else {
        button.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.92];
        button.layer.cornerRadius = 7.0;
        button.layer.borderColor = [UIColor colorWithWhite:0.65 alpha:1.0].CGColor;
        button.layer.borderWidth = 1.0;
        button.layer.shadowOpacity = 0.0;
        [button setTitleColor:[UIColor darkTextColor] forState:UIControlStateNormal];
    }
}

- (UIImage *)tintedImageNamed:(NSString *)name color:(UIColor *)color {
    UIImage *source = [UIImage imageNamed:name];
    if (!source) return nil;
    UIGraphicsBeginImageContextWithOptions(source.size, NO, source.scale);
    CGRect rect = CGRectMake(0, 0, source.size.width, source.size.height);
    [color setFill];
    UIRectFill(rect);
    [source drawInRect:rect blendMode:kCGBlendModeDestinationIn alpha:1.0];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

- (UIButton *)tabButtonWithTitle:(NSString *)title imageName:(NSString *)imageName tag:(NSInteger)tag action:(SEL)action width:(CGFloat)width {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(tag * width, 0, width, 58);
    button.tag = tag;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    UIImageView *icon = [[[UIImageView alloc] initWithFrame:CGRectMake((width - 24) / 2.0, 5, 24, 24)] autorelease];
    icon.tag = 100;
    icon.contentMode = UIViewContentModeScaleAspectFit;
    icon.accessibilityIdentifier = imageName;
    [button addSubview:icon];
    UILabel *label = [[[UILabel alloc] initWithFrame:CGRectMake(1, 31, width - 2, 20)] autorelease];
    label.tag = 101;
    label.backgroundColor = [UIColor clearColor];
    label.font = [UIFont systemFontOfSize:10.5];
    label.textAlignment = NSTextAlignmentCenter;
    label.text = title;
    [button addSubview:label];
    button.accessibilityLabel = title;
    return button;
}

- (UIImage *)classicTabBarBackgroundImage {
    CGSize size = CGSizeMake(2.0, 58.0);
    UIGraphicsBeginImageContextWithOptions(size, YES, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    NSArray *colors = [NSArray arrayWithObjects:
                       (id)[UIColor colorWithRed:0.43 green:0.68 blue:0.88 alpha:1.0].CGColor,
                       (id)[UIColor colorWithRed:0.10 green:0.40 blue:0.68 alpha:1.0].CGColor, nil];
    CGFloat locations[] = { 0.0, 1.0 };
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (CFArrayRef)colors, locations);
    CGContextDrawLinearGradient(context, gradient, CGPointMake(0, 0), CGPointMake(0, size.height), 0);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (void)styleBottomTabBar {
    BOOL classic = STCurrentThemeStyle() == STThemeStyleIOS6;
    self.bottomTabBar.layer.contents = classic ? (id)[self classicTabBarBackgroundImage].CGImage : nil;
    self.bottomTabBar.layer.contentsGravity = kCAGravityResize;
    self.bottomTabBar.backgroundColor = classic ? [UIColor clearColor]
        : (STDarkThemeEnabled() ? [UIColor colorWithRed:0.07 green:0.08 blue:0.10 alpha:0.95]
                                : [UIColor colorWithWhite:1.0 alpha:0.95]);
    self.bottomTabBar.layer.borderColor = (STDarkThemeEnabled()
        ? [UIColor colorWithWhite:0.28 alpha:1.0]
        : (classic ? [UIColor colorWithRed:0.06 green:0.30 blue:0.56 alpha:1.0]
                   : [UIColor colorWithWhite:0.72 alpha:1.0])).CGColor;
    self.bottomTabBar.layer.borderWidth = 0.5;
    NSArray *imageNames = [NSArray arrayWithObjects:@"tab-map.png", @"tab-routes.png", @"tab-settings.png", @"tab-favorites.png", nil];
    NSUInteger index;
    for (index = 0; index < self.bottomTabButtons.count; index++) {
        UIButton *button = [self.bottomTabButtons objectAtIndex:index];
        BOOL selected = index == 0;
        UIColor *color = selected ? (classic ? [UIColor whiteColor] : STTintColor())
            : (classic ? [UIColor colorWithRed:0.80 green:0.91 blue:0.98 alpha:1.0]
                       : (STDarkThemeEnabled() ? [UIColor colorWithWhite:0.78 alpha:1.0] : [UIColor colorWithWhite:0.25 alpha:1.0]));
        button.backgroundColor = selected && classic ? [UIColor colorWithWhite:0.0 alpha:0.18] : [UIColor clearColor];
        UIImageView *icon = (UIImageView *)[button viewWithTag:100];
        icon.image = [self tintedImageNamed:[imageNames objectAtIndex:index] color:color];
        UILabel *label = (UILabel *)[button viewWithTag:101];
        label.textColor = color;
    }
}

- (void)loadView {
    UIView *root = [[[UIView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]] autorelease];
    root.backgroundColor = [UIColor whiteColor];
    self.mapView = [[[MKMapView alloc] initWithFrame:root.bounds] autorelease];
    self.mapView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.mapView.delegate = self;
    self.mapView.showsUserLocation = YES;
    [root addSubview:self.mapView];

    self.bottomTabBar = [[[UIView alloc] initWithFrame:CGRectMake(0, root.bounds.size.height - 58, root.bounds.size.width, 58)] autorelease];
    self.bottomTabBar.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    CGFloat tabWidth = root.bounds.size.width / 4.0;
    UIButton *mapTab = [self tabButtonWithTitle:@"Карта" imageName:@"tab-map.png" tag:0 action:@selector(selectMapTab) width:tabWidth];
    UIButton *routesTab = [self tabButtonWithTitle:@"Маршруты" imageName:@"tab-routes.png" tag:1 action:@selector(showRoutes) width:tabWidth];
    UIButton *settingsTab = [self tabButtonWithTitle:@"Настройки" imageName:@"tab-settings.png" tag:2 action:@selector(showMenu) width:tabWidth];
    UIButton *favoritesTab = [self tabButtonWithTitle:@"Избранное" imageName:@"tab-favorites.png" tag:3 action:@selector(showFavorites) width:tabWidth];
    self.bottomTabButtons = [NSArray arrayWithObjects:mapTab, routesTab, settingsTab, favoritesTab, nil];
    for (UIButton *button in self.bottomTabButtons) [self.bottomTabBar addSubview:button];
    [root addSubview:self.bottomTabBar];
    [self styleBottomTabBar];

    UIButton *zoomIn = [self controlButtonWithTitle:@"" action:@selector(zoomIn)];
    zoomIn.tag = 700;
    [self styleMapControl:zoomIn];
    zoomIn.frame = CGRectMake(root.bounds.size.width - 52, root.bounds.size.height - 204, 44, 44);
    zoomIn.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin;
    [zoomIn setImage:[UIImage imageNamed:@"zoom-plus.png"] forState:UIControlStateNormal];
    zoomIn.accessibilityLabel = @"Приблизить карту";
    [root addSubview:zoomIn];

    UIButton *zoomOut = [self controlButtonWithTitle:@"" action:@selector(zoomOut)];
    zoomOut.tag = 700;
    [self styleMapControl:zoomOut];
    zoomOut.frame = CGRectMake(root.bounds.size.width - 52, root.bounds.size.height - 156, 44, 44);
    zoomOut.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin;
    [zoomOut setImage:[UIImage imageNamed:@"zoom-minus.png"] forState:UIControlStateNormal];
    zoomOut.accessibilityLabel = @"Отдалить карту";
    [root addSubview:zoomOut];

    UIButton *location = [self controlButtonWithTitle:@"" action:@selector(showLocation)];
    location.tag = 700;
    [self styleMapControl:location];
    location.frame = CGRectMake(root.bounds.size.width - 52, root.bounds.size.height - 108, 44, 44);
    location.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin;
    [location setImage:[UIImage imageNamed:@"location-button.png"] forState:UIControlStateNormal];
    location.accessibilityLabel = @"Моё местоположение";
    [root addSubview:location];

    self.statusLabel = [[[UILabel alloc] initWithFrame:CGRectMake(20, 12, root.bounds.size.width - 40, 32)] autorelease];
    self.statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.statusLabel.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.9];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.font = [UIFont boldSystemFontOfSize:13];
    self.statusLabel.layer.cornerRadius = 6.0;
    self.statusLabel.layer.masksToBounds = YES;
    self.statusLabel.text = @"Загрузка данных…";
    [root addSubview:self.statusLabel];

    self.routeCloseButton = [self controlButtonWithTitle:@"" action:@selector(closeSelectedRoutes)];
    self.routeCloseButton.tag = 700;
    [self styleMapControl:self.routeCloseButton];
    self.routeCloseButton.frame = CGRectMake(root.bounds.size.width - 44, 8, 36, 36);
    self.routeCloseButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self.routeCloseButton setImage:[UIImage imageNamed:@"route-close.png"] forState:UIControlStateNormal];
    self.routeCloseButton.accessibilityLabel = @"Закрыть выбранный маршрут и вернуть обычную карту";
    self.routeCloseButton.hidden = YES;
    [root addSubview:self.routeCloseButton];
    self.view = root;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    UIBarButtonItem *search = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(showSearch)] autorelease];
    UIBarButtonItem *refreshMap = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refreshMapNow)] autorelease];
    self.stationToggleButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.stationToggleButton.frame = CGRectMake(0, 0, 28, 28);
    self.stationToggleButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.stationToggleButton setImage:[UIImage imageNamed:@"station-bus.png"] forState:UIControlStateNormal];
    [self.stationToggleButton addTarget:self action:@selector(toggleStationIcons) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *stations = [[[UIBarButtonItem alloc] initWithCustomView:self.stationToggleButton] autorelease];
    self.vehicleFlagsButton = [[[UIBarButtonItem alloc] initWithTitle:@"ТС"
                                                               style:UIBarButtonItemStylePlain
                                                              target:self action:@selector(toggleVehicleFlags)] autorelease];
    // First item is rightmost: Search, ТС, Refresh, then the stop toggle.
    self.navigationItem.rightBarButtonItems = [NSArray arrayWithObjects:search, self.vehicleFlagsButton, refreshMap, stations, nil];
    [self updateStationToggleButton];
    [self updateVehicleFlagsButton];
    [self updateRouteCloseButton];
    self.navigationItem.leftBarButtonItem = nil;
    [self applyMapType];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(storeReloaded:) name:STStoreDidReloadNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cityChanged:) name:STStoreCityDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyMapType) name:STMapTypeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stationVisibilityChanged:) name:STStationVisibilityDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(visibleRoutesChanged:) name:STVisibleRoutesDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(themeChanged:) name:STThemeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [self centerOnSelectedCityAnimated:NO];
    [[STStore sharedStore] loadInitialData:^(NSError *error) {
        if (error && [STStore sharedStore].stations.count == 0) STShowError(self, [error localizedDescription]);
    }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.mapIsVisible = YES;
    NSTimeInterval now = CACurrentMediaTime();
    if (self.lastVehicleUpdateAt <= 0.0 || now - self.lastVehicleUpdateAt > 7.0) {
        self.snapNextVehicleUpdate = YES;
        self.vehicleAnimationKey = 0;
    }
    [self updateTitle];
    [self applyMapTheme];
    [self updateStationToggleButton];
    [self updateVehicleFlagsButton];
    [self restartVehicleTimer];
    // Do not wait for the first timer tick when returning to the map.
    [self refreshVehicles];
}

- (void)restartVehicleTimer {
    [self.vehicleTimer invalidate];
    self.vehicleTimer = [NSTimer timerWithTimeInterval:5.0 target:self selector:@selector(refreshVehicles) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.vehicleTimer forMode:NSRunLoopCommonModes];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification {
    self.mapIsVisible = NO;
    [self.vehicleTimer invalidate];
    self.vehicleTimer = nil;
    self.vehicleGeneration++;
    self.vehicleRequestInFlight = NO;
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    if (self.navigationController.topViewController != self || !self.view.window) return;
    self.mapIsVisible = YES;
    NSTimeInterval now = CACurrentMediaTime();
    if (self.lastVehicleUpdateAt <= 0.0 || now - self.lastVehicleUpdateAt > 7.0) {
        self.snapNextVehicleUpdate = YES;
        self.vehicleAnimationKey = 0;
    }
    [self restartVehicleTimer];
    [self refreshVehicles];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.mapIsVisible = NO;
    [self.vehicleTimer invalidate];
    self.vehicleTimer = nil;
    self.vehicleGeneration++;
    self.vehicleRequestInFlight = NO;
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(startPendingVehicleAnimations) object:nil];
    for (STAnnotation *annotation in self.vehicleAnnotations) {
        [[[self.mapView viewForAnnotation:annotation] layer] removeAnimationForKey:@"STVehicleMovement"];
    }
}

- (void)applyMapType {
    NSInteger type = [[NSUserDefaults standardUserDefaults] integerForKey:@"STMapType"];
    if (type < 0 || type > 2) type = 0;
    self.mapView.mapType = (MKMapType)type;
}

- (void)applyMapTheme {
    STApplyNavigationTheme(self.navigationController);
    for (UIView *view in self.view.subviews) {
        if ([view isKindOfClass:[UIButton class]]) [self styleMapControl:(UIButton *)view];
    }
    self.statusLabel.backgroundColor = STDarkThemeEnabled()
        ? [UIColor colorWithRed:0.07 green:0.08 blue:0.10 alpha:0.92]
        : (STIOS7ThemeEnabled() ? [UIColor colorWithWhite:1.0 alpha:0.94] : [UIColor colorWithWhite:1.0 alpha:0.9]);
    self.statusLabel.textColor = STDarkThemeEnabled() ? [UIColor whiteColor]
        : (STIOS7ThemeEnabled() ? [UIColor colorWithWhite:0.15 alpha:1.0] : [UIColor darkTextColor]);
    [self styleBottomTabBar];
    if (STDarkThemeEnabled() && !self.darkMapOverlay) {
        self.darkMapOverlay = [[[STDarkMapOverlay alloc] init] autorelease];
        [self.mapView insertOverlay:self.darkMapOverlay atIndex:0];
    } else if (!STDarkThemeEnabled() && self.darkMapOverlay) {
        [self.mapView removeOverlay:self.darkMapOverlay];
        self.darkMapOverlay = nil;
    }
}

- (void)themeChanged:(NSNotification *)notification {
    [self applyMapTheme];
    for (STAnnotation *annotation in self.vehicleAnnotations) {
        STVehicleAnnotationView *view = (STVehicleAnnotationView *)[self.mapView viewForAnnotation:annotation];
        if ([view isKindOfClass:[STVehicleAnnotationView class]]) [view configureWithVehicle:annotation.data showFeatureFlag:[self vehicleFlagsEnabled]];
    }
}

- (void)updateRouteCloseButton {
    BOOL visible = self.currentRoutes.count > 0;
    self.routeCloseButton.hidden = !visible;
    CGRect statusFrame = self.statusLabel.frame;
    statusFrame.size.width = self.view.bounds.size.width - (visible ? 80.0 : 40.0);
    self.statusLabel.frame = statusFrame;
}

- (void)clearDisplayedRoutes {
    self.routeLoadGeneration++;
    if (self.routeOverlays.count) [self.mapView removeOverlays:self.routeOverlays];
    [self.routeOverlays removeAllObjects];
    self.currentRoutes = nil;
    [self updateRouteCloseButton];
}

- (void)closeSelectedRoutes {
    [self clearDisplayedRoutes];
    [self clearVehicleAnnotations];
    self.statusLabel.alpha = 1.0;
    self.statusLabel.text = @"Обычная карта и включённые маршруты восстановлены";
    [UIView animateWithDuration:0.3 delay:1.3 options:0 animations:^{ self.statusLabel.alpha = 0.0; } completion:nil];
    [self refreshVehicles];
}

- (void)visibleRoutesChanged:(NSNotification *)notification {
    [self clearDisplayedRoutes];
    [self clearVehicleAnnotations];
    [self refreshVehicles];
}

- (void)updateStationToggleButton {
    BOOL enabled = STStationIconsEnabled();
    self.stationToggleButton.alpha = enabled ? 1.0 : 0.35;
    self.stationToggleButton.selected = enabled;
    self.stationToggleButton.accessibilityLabel = enabled
        ? @"Скрыть фиолетовые значки остановок"
        : @"Показать фиолетовые значки остановок";
}

- (void)toggleStationIcons {
    STSetStationIconsEnabled(!STStationIconsEnabled());
}

- (BOOL)vehicleFlagsEnabled {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"STShowVehicleFlags"];
}

- (void)updateVehicleFlagsButton {
    BOOL enabled = [self vehicleFlagsEnabled];
    self.vehicleFlagsButton.style = enabled ? UIBarButtonItemStyleDone : UIBarButtonItemStylePlain;
    self.vehicleFlagsButton.title = enabled ? @"ТС•" : @"ТС";
    self.vehicleFlagsButton.accessibilityLabel = enabled ? @"Скрыть класс транспорта" : @"Показать класс транспорта";
}

- (void)toggleVehicleFlags {
    BOOL enabled = ![self vehicleFlagsEnabled];
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:@"STShowVehicleFlags"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self updateVehicleFlagsButton];
    self.statusLabel.alpha = 1.0;
    self.statusLabel.text = enabled
        ? @"♿ низкий пол · Wi‑Fi · ❄ A/C · К коляска"
        : @"Флажки класса ТС скрыты";
    [UIView animateWithDuration:0.3 delay:2.0 options:0 animations:^{ self.statusLabel.alpha = 0.0; } completion:nil];
    for (STAnnotation *annotation in self.vehicleAnnotations) {
        STVehicleAnnotationView *view = (STVehicleAnnotationView *)[self.mapView viewForAnnotation:annotation];
        if ([view isKindOfClass:[STVehicleAnnotationView class]]) {
            [view configureWithVehicle:annotation.data showFeatureFlag:enabled];
        }
    }
}

- (void)stationVisibilityChanged:(NSNotification *)notification {
    [self updateStationToggleButton];
    [self reloadStationAnnotations];
    self.statusLabel.alpha = 1.0;
    self.statusLabel.text = !STStationIconsEnabled() ? @"Значки остановок скрыты"
        : (self.stationAnnotations.count
           ? [NSString stringWithFormat:@"Показано остановок: %lu", (unsigned long)self.stationAnnotations.count]
           : @"Остановки появятся при приближении карты");
    [UIView animateWithDuration:0.3 delay:1.0 options:0 animations:^{ self.statusLabel.alpha = 0.0; } completion:nil];
}

- (void)updateTitle {
    NSString *city = STString([[[STStore sharedStore] selectedCity] objectForKey:@"name"]);
    self.title = city.length ? city : @"Умный транспорт";
}

- (void)centerOnSelectedCityAnimated:(BOOL)animated {
    CLLocationCoordinate2D center = [[STStore sharedStore] selectedCityCoordinate];
    if (!CLLocationCoordinate2DIsValid(center)) return;
    MKCoordinateRegion region = MKCoordinateRegionMake(center, MKCoordinateSpanMake(0.16, 0.16));
    [self.mapView setRegion:region animated:animated];
}

- (void)storeReloaded:(NSNotification *)notification {
    [self updateTitle];
    [self reloadStationAnnotations];
    self.statusLabel.text = STStationIconsEnabled()
        ? [NSString stringWithFormat:@"Остановки при приближении · маршрутов: %lu",
           (unsigned long)[STStore sharedStore].routes.count]
        : [NSString stringWithFormat:@"Остановки скрыты · маршрутов: %lu",
           (unsigned long)[STStore sharedStore].routes.count];
    [UIView animateWithDuration:0.4 delay:1.2 options:0 animations:^{ self.statusLabel.alpha = 0.0; } completion:nil];
    [self refreshVehicles];
}

- (void)cityChanged:(NSNotification *)notification {
    self.statusLabel.alpha = 1.0;
    self.statusLabel.text = @"Загрузка данных города…";
    [self clearDisplayedRoutes];
    [self clearVehicleAnnotations];
    [self centerOnSelectedCityAnimated:NO];
}

- (CLLocationCoordinate2D)coordinateForStation:(NSDictionary *)station {
    return CLLocationCoordinate2DMake(STCoordinateValue([station objectForKey:@"lat0"]), STCoordinateValue([station objectForKey:@"lon0"]));
}

- (void)reloadStationAnnotations {
    BOOL zoomedIn = self.mapView.region.span.latitudeDelta <= 0.055
        && self.mapView.region.span.longitudeDelta <= 0.075;
    if (!STStationIconsEnabled() || !zoomedIn) {
        if (self.stationAnnotations.count) [self.mapView removeAnnotations:self.stationAnnotations];
        [self.stationAnnotations removeAllObjects];
        return;
    }

    MKMapRect visible = self.mapView.visibleMapRect;
    MKMapRect padded = MKMapRectInset(visible, -visible.size.width * 0.08, -visible.size.height * 0.08);
    NSMutableArray *candidates = [NSMutableArray array];
    for (NSDictionary *station in [STStore sharedStore].stations) {
        CLLocationCoordinate2D coordinate = [self coordinateForStation:station];
        if (!CLLocationCoordinate2DIsValid(coordinate) || coordinate.latitude == 0 || coordinate.longitude == 0) continue;
        if (MKMapRectContainsPoint(padded, MKMapPointForCoordinate(coordinate))) [candidates addObject:station];
    }
    if (candidates.count > 160) {
        MKMapPoint center = MKMapPointForCoordinate(self.mapView.region.center);
        [candidates sortUsingComparator:^NSComparisonResult(id first, id second) {
            double a = MKMetersBetweenMapPoints(center, MKMapPointForCoordinate([self coordinateForStation:first]));
            double b = MKMetersBetweenMapPoints(center, MKMapPointForCoordinate([self coordinateForStation:second]));
            return a < b ? NSOrderedAscending : (a > b ? NSOrderedDescending : NSOrderedSame);
        }];
        [candidates removeObjectsInRange:NSMakeRange(160, candidates.count - 160)];
    }

    NSMutableDictionary *existing = [NSMutableDictionary dictionary];
    for (STAnnotation *annotation in self.stationAnnotations) {
        [existing setObject:annotation forKey:[NSNumber numberWithInteger:STInteger([annotation.data objectForKey:@"id"])]];
    }
    NSMutableArray *additions = [NSMutableArray array];
    for (NSDictionary *station in candidates) {
        NSNumber *identifier = [NSNumber numberWithInteger:STInteger([station objectForKey:@"id"])];
        if ([existing objectForKey:identifier]) {
            [existing removeObjectForKey:identifier];
            continue;
        }
        STAnnotation *annotation = [STAnnotation annotationWithCoordinate:[self coordinateForStation:station]
                                                                   title:STString([station objectForKey:@"name"])
                                                                subtitle:STString([station objectForKey:@"description"])
                                                                    data:station kind:STAnnotationKindStation];
        [additions addObject:annotation];
    }
    NSArray *removals = [existing allValues];
    if (removals.count) {
        [self.mapView removeAnnotations:removals];
        [self.stationAnnotations removeObjectsInArray:removals];
    }
    if (additions.count) {
        [self.stationAnnotations addObjectsFromArray:additions];
        [self.mapView addAnnotations:additions];
    }
}

- (void)showMenu {
    STMenuViewController *menu = [[[STMenuViewController alloc] initWithRouteDelegate:self location:self.currentLocation] autorelease];
    [self.navigationController pushViewController:menu animated:YES];
}

- (void)selectMapTab {
    [self refreshVehicles];
}

- (void)showRoutes {
    STRoutesViewController *routes = [[[STRoutesViewController alloc] initWithFavoritesOnly:NO] autorelease];
    routes.delegate = self;
    [self.navigationController pushViewController:routes animated:YES];
}

- (void)showFavorites {
    STFavoritesViewController *favorites = [[[STFavoritesViewController alloc] initWithRouteDelegate:self] autorelease];
    [self.navigationController pushViewController:favorites animated:YES];
}

- (void)showSettings {
    [self.navigationController pushViewController:[[[STSettingsViewController alloc] init] autorelease] animated:YES];
}

- (void)zoomByFactor:(double)factor {
    MKCoordinateRegion region = self.mapView.region;
    region.span.latitudeDelta = MIN(80.0, MAX(0.0015, region.span.latitudeDelta * factor));
    region.span.longitudeDelta = MIN(160.0, MAX(0.0015, region.span.longitudeDelta * factor));
    [self.mapView setRegion:region animated:YES];
}

- (void)zoomIn { [self zoomByFactor:0.55]; }
- (void)zoomOut { [self zoomByFactor:1.8]; }

- (void)showSearch {
    STStationListViewController *search = [[[STStationListViewController alloc] initWithMode:STStationListModeAll location:self.currentLocation] autorelease];
    [self.navigationController pushViewController:search animated:YES];
}

- (void)showCityMenu {
    STMenuViewController *menu = [[[STMenuViewController alloc] initWithRouteDelegate:self location:self.currentLocation] autorelease];
    [self.navigationController pushViewController:menu animated:YES];
}

- (void)showLocation {
    if (!self.locationManager) {
        self.locationManager = [[[CLLocationManager alloc] init] autorelease];
        self.locationManager.delegate = self;
        self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
    }
    [self.locationManager startUpdatingLocation];
    self.statusLabel.alpha = 1.0;
    self.statusLabel.text = @"Определение местоположения…";
}

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {
    if (newLocation.horizontalAccuracy < 0) return;
    self.currentLocation = newLocation;
    [manager stopUpdatingLocation];
    MKCoordinateRegion region = MKCoordinateRegionMake(newLocation.coordinate, MKCoordinateSpanMake(0.025, 0.025));
    [self.mapView setRegion:region animated:YES];
    self.statusLabel.alpha = 0.0;
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    [manager stopUpdatingLocation];
    self.statusLabel.alpha = 0.0;
    STShowError(self, @"Не удалось определить местоположение");
}

- (void)refresh {
    self.statusLabel.alpha = 1.0;
    self.statusLabel.text = @"Обновление данных…";
    [[STStore sharedStore] selectCityCode:[STStore sharedStore].cityCode completion:^(NSError *error) {
        if (error) STShowError(self, [error localizedDescription]);
    }];
}

- (void)refreshMapNow {
    self.statusLabel.alpha = 1.0;
    self.statusLabel.text = @"Обновление карты…";
    [self reloadStationAnnotations];
    self.vehicleGeneration++;
    self.vehicleRequestInFlight = NO;
    self.vehicleAnimationKey = 0;
    self.snapNextVehicleUpdate = YES;
    [self refreshVehicles];
    [UIView animateWithDuration:0.3 delay:1.0 options:0 animations:^{ self.statusLabel.alpha = 0.0; } completion:nil];
}

- (NSString *)visibleRouteIDs {
    NSMutableArray *ids = [NSMutableArray array];
    if (self.currentRoutes.count) {
        for (NSDictionary *route in self.currentRoutes) [ids addObject:STString([route objectForKey:@"id"])];
    } else {
        for (NSNumber *identifier in [[STStore sharedStore] visibleRouteIDs]) [ids addObject:[identifier description]];
    }
    return [ids componentsJoinedByString:@","];
}

- (CLLocationCoordinate2D)unmaskedCoordinateWithLatitude:(id)latitude longitude:(id)longitude {
    return CLLocationCoordinate2DMake((STDouble(latitude) + 12345.0) / 1000000.0,
                                      (STDouble(longitude) + 12345.0) / 1000000.0);
}

- (NSValue *)valueWithCoordinate:(CLLocationCoordinate2D)coordinate {
    return [NSValue value:&coordinate withObjCType:@encode(CLLocationCoordinate2D)];
}

- (CLLocationCoordinate2D)visualCoordinateForAnnotation:(STAnnotation *)annotation {
    MKAnnotationView *view = [self.mapView viewForAnnotation:annotation];
    CALayer *presentation = (CALayer *)[view.layer presentationLayer];
    if (view && presentation) {
        CGPoint point = presentation.position;
        point.x -= view.centerOffset.x;
        point.y -= view.centerOffset.y;
        return [self.mapView convertPoint:point toCoordinateFromView:view.superview];
    }
    return annotation.coordinate;
}

- (double)forwardProjectionFrom:(CLLocationCoordinate2D)current
                              to:(CLLocationCoordinate2D)target
                     motionStart:(CLLocationCoordinate2D)motionStart
                       motionEnd:(CLLocationCoordinate2D)motionEnd {
    double latitudeRadians = current.latitude * M_PI / 180.0;
    double scale = cos(latitudeRadians);
    double motionNorth = (motionEnd.latitude - motionStart.latitude) * 111320.0;
    double motionEast = (motionEnd.longitude - motionStart.longitude) * 111320.0 * scale;
    double length = sqrt(motionNorth * motionNorth + motionEast * motionEast);
    if (length < 1.0) return 0.0;
    double targetNorth = (target.latitude - current.latitude) * 111320.0;
    double targetEast = (target.longitude - current.longitude) * 111320.0 * scale;
    return (targetNorth * motionNorth + targetEast * motionEast) / length;
}

- (NSString *)destinationForVehicle:(NSDictionary *)vehicle {
    NSDictionary *route = [[STStore sharedStore] routeWithID:STInteger([vehicle objectForKey:@"rid"])];
    NSString *destination = STString([route objectForKey:@"to_station_name"]);
    if (!destination.length) {
        NSDictionary *station = [[STStore sharedStore] stationWithID:STInteger([route objectForKey:@"to_station_id"])];
        destination = STString([station objectForKey:@"name"]);
    }
    return destination.length ? destination : @"по маршруту";
}

- (void)clearVehicleAnnotations {
    self.vehicleGeneration++;
    self.vehicleRequestInFlight = NO;
    self.vehicleAnimationKey = 0;
    if (self.vehicleAnnotations.count) [self.mapView removeAnnotations:self.vehicleAnnotations];
    [self.vehicleAnnotations removeAllObjects];
    [self.vehicleAnnotationsByID removeAllObjects];
}

- (void)removeStaleVehiclesAtTime:(NSTimeInterval)time {
    NSMutableArray *stale = [NSMutableArray array];
    for (STAnnotation *annotation in self.vehicleAnnotations) {
        if (time - annotation.lastSeenAt > 120.0) [stale addObject:annotation];
    }
    if (!stale.count) return;
    [self.mapView removeAnnotations:stale];
    for (STAnnotation *annotation in stale) {
        NSString *identifier = STString([annotation.data objectForKey:@"id"]);
        if (identifier.length) [self.vehicleAnnotationsByID removeObjectForKey:identifier];
        [self.vehicleAnnotations removeObject:annotation];
    }
}

- (void)animatePendingVehicle:(STAnnotation *)annotation {
    if (annotation.movementPath.count == 0) return;
    CLLocationCoordinate2D finalCoordinate;
    [[annotation.movementPath lastObject] getValue:&finalCoordinate];
    MKMapPoint mapPoint = MKMapPointForCoordinate(annotation.coordinate);
    MKAnnotationView *view = [self.mapView viewForAnnotation:annotation];
    if (!view || !MKMapRectContainsPoint(self.mapView.visibleMapRect, mapPoint)) {
        annotation.coordinate = finalCoordinate;
        [annotation finishMovement];
        return;
    }

    NSMutableArray *values = [NSMutableArray arrayWithCapacity:annotation.movementPath.count + 1];
    CALayer *presentation = (CALayer *)[view.layer presentationLayer];
    CGPoint currentPoint = presentation ? presentation.position
        : [self.mapView convertCoordinate:annotation.coordinate toPointToView:view.superview];
    if (!presentation) {
        currentPoint.x += view.centerOffset.x;
        currentPoint.y += view.centerOffset.y;
    }
    [values addObject:[NSValue valueWithCGPoint:currentPoint]];
    for (NSValue *coordinateValue in annotation.movementPath) {
        CLLocationCoordinate2D coordinate;
        [coordinateValue getValue:&coordinate];
        CGPoint point = [self.mapView convertCoordinate:coordinate toPointToView:view.superview];
        point.x += view.centerOffset.x;
        point.y += view.centerOffset.y;
        [values addObject:[NSValue valueWithCGPoint:point]];
    }

    double total = 0.0;
    for (NSNumber *weight in annotation.movementWeights) total += MAX(0.01, [weight doubleValue]);
    if (total <= 0.0) total = (double)annotation.movementPath.count;
    NSMutableArray *keyTimes = [NSMutableArray arrayWithObject:[NSNumber numberWithDouble:0.0]];
    double passed = 0.0;
    NSUInteger index;
    for (index = 0; index < annotation.movementPath.count; index++) {
        double weight = index < annotation.movementWeights.count
            ? MAX(0.01, [[annotation.movementWeights objectAtIndex:index] doubleValue]) : 1.0;
        passed += weight;
        [keyTimes addObject:[NSNumber numberWithDouble:MIN(1.0, passed / total)]];
    }

    annotation.coordinate = finalCoordinate;
    CAKeyframeAnimation *movement = [CAKeyframeAnimation animationWithKeyPath:@"position"];
    movement.values = values;
    movement.keyTimes = keyTimes;
    movement.duration = annotation.movementDuration;
    movement.calculationMode = kCAAnimationLinear;
    movement.removedOnCompletion = YES;
    [view.layer removeAnimationForKey:@"STVehicleMovement"];
    [view.layer addAnimation:movement forKey:@"STVehicleMovement"];
    [annotation finishMovement];
}

- (void)startPendingVehicleAnimations {
    for (STAnnotation *annotation in self.vehicleAnnotations) {
        if (annotation.movementPath.count) [self animatePendingVehicle:annotation];
    }
}

- (void)applyVehiclePayload:(NSArray *)vehicles atTime:(NSTimeInterval)time {
    BOOL snap = self.snapNextVehicleUpdate;
    NSMutableArray *newAnnotations = [NSMutableArray array];
    for (NSDictionary *rawVehicle in vehicles) {
        NSString *identifier = STString([rawVehicle objectForKey:@"id"]);
        if (!identifier.length || [identifier isEqualToString:@"need verify"]) continue;
        CLLocationCoordinate2D finalCoordinate = [self unmaskedCoordinateWithLatitude:[rawVehicle objectForKey:@"lat"]
                                                                             longitude:[rawVehicle objectForKey:@"lng"]];
        if (!CLLocationCoordinate2DIsValid(finalCoordinate)) continue;

        NSString *destination = [self destinationForVehicle:rawVehicle];
        NSMutableDictionary *vehicle = [[rawVehicle mutableCopy] autorelease];
        [vehicle setObject:destination forKey:@"_destination"];
        NSString *routeNumber = STString([vehicle objectForKey:@"rnum"]);
        NSString *title = [NSString stringWithFormat:@"%@ №%@ → %@", STTransportName(STString([vehicle objectForKey:@"rtype"])), routeNumber, destination];
        STAnnotation *annotation = [self.vehicleAnnotationsByID objectForKey:identifier];
        CLLocationCoordinate2D oldBaseCoordinate = finalCoordinate;
        CLLocationCoordinate2D visualCoordinate = finalCoordinate;
        if (annotation) {
            oldBaseCoordinate = [self unmaskedCoordinateWithLatitude:[annotation.data objectForKey:@"lat"]
                                                            longitude:[annotation.data objectForKey:@"lng"]];
            visualCoordinate = [self visualCoordinateForAnnotation:annotation];
        }
        NSMutableArray *path = [NSMutableArray array];
        NSMutableArray *weights = [NSMutableArray array];
        NSArray *animationPoints = [vehicle objectForKey:@"anim_points"];
        if ([animationPoints isKindOfClass:[NSArray class]]) {
            for (NSDictionary *point in animationPoints) {
                CLLocationCoordinate2D coordinate = [self unmaskedCoordinateWithLatitude:[point objectForKey:@"lat"]
                                                                                 longitude:[point objectForKey:@"lon"]];
                if (!CLLocationCoordinate2DIsValid(coordinate)) continue;
                [path addObject:[self valueWithCoordinate:coordinate]];
                [weights addObject:[NSNumber numberWithDouble:MAX(1.0, STDouble([point objectForKey:@"percent"]))]];
            }
        }
        // anim_points are already an ordered prediction beyond the reported
        // base position. Appending the base after them makes every vehicle run
        // to the prediction and then jump backwards.
        if (!path.count) {
            [path addObject:[self valueWithCoordinate:finalCoordinate]];
            [weights addObject:[NSNumber numberWithDouble:100.0]];
        }

        if (annotation && !snap && path.count) {
            double motionLength = MKMetersBetweenMapPoints(MKMapPointForCoordinate(oldBaseCoordinate), MKMapPointForCoordinate(finalCoordinate));
            NSUInteger nearestIndex = NSNotFound;
            double nearestDistance = DBL_MAX;
            NSUInteger pointIndex;
            for (pointIndex = 0; pointIndex < path.count; pointIndex++) {
                CLLocationCoordinate2D pointCoordinate;
                [[path objectAtIndex:pointIndex] getValue:&pointCoordinate];
                double forward = [self forwardProjectionFrom:visualCoordinate to:pointCoordinate
                                                 motionStart:oldBaseCoordinate motionEnd:finalCoordinate];
                if (motionLength >= 1.0 && forward < -2.0) continue;
                double distance = MKMetersBetweenMapPoints(MKMapPointForCoordinate(visualCoordinate), MKMapPointForCoordinate(pointCoordinate));
                if (distance < nearestDistance) {
                    nearestDistance = distance;
                    nearestIndex = pointIndex;
                }
            }
            if (nearestIndex == NSNotFound) {
                [path removeAllObjects];
                [weights removeAllObjects];
            } else if (nearestIndex > 0) {
                [path removeObjectsInRange:NSMakeRange(0, nearestIndex)];
                [weights removeObjectsInRange:NSMakeRange(0, nearestIndex)];
            }
        }

        if (!annotation) {
            CLLocationCoordinate2D initial = finalCoordinate;
            if (!snap && path.count) [[path objectAtIndex:0] getValue:&initial];
            annotation = [STAnnotation annotationWithCoordinate:initial title:title
                                                        subtitle:STString([vehicle objectForKey:@"gos_num"])
                                                            data:vehicle kind:STAnnotationKindVehicle];
            [self.vehicleAnnotationsByID setObject:annotation forKey:identifier];
            [self.vehicleAnnotations addObject:annotation];
            [newAnnotations addObject:annotation];
            if (!snap && path.count > 1) {
                [path removeObjectAtIndex:0];
                [weights removeObjectAtIndex:0];
            }
        } else {
            annotation.title = title;
            annotation.subtitle = STString([vehicle objectForKey:@"gos_num"]);
            annotation.data = vehicle;
        }
        annotation.lastSeenAt = time;
        if (snap) {
            annotation.coordinate = finalCoordinate;
            [annotation finishMovement];
        } else if (path.count) {
            [annotation beginMovementAlongPath:path weights:weights duration:6.8 atTime:time];
        }

        STVehicleAnnotationView *view = (STVehicleAnnotationView *)[self.mapView viewForAnnotation:annotation];
        if ([view isKindOfClass:[STVehicleAnnotationView class]]) [view configureWithVehicle:vehicle showFeatureFlag:[self vehicleFlagsEnabled]];
        NSInteger animationKey = STInteger([vehicle objectForKey:@"anim_key"]);
        if (animationKey > self.vehicleAnimationKey) self.vehicleAnimationKey = animationKey;
    }
    if (newAnnotations.count) [self.mapView addAnnotations:newAnnotations];
    [self removeStaleVehiclesAtTime:time];
    self.lastVehicleUpdateAt = time;
    self.snapNextVehicleUpdate = NO;
    // Give MapKit one run-loop turn to create views for new annotations, then
    // hand movement to Core Animation. No per-frame Objective-C loop is used.
    if (!snap) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(startPendingVehicleAnimations) object:nil];
        [self performSelector:@selector(startPendingVehicleAnimations) withObject:nil afterDelay:0.0];
    }
}

- (void)refreshVehicles {
    if (!self.mapIsVisible || [STStore sharedStore].routes.count == 0 || self.vehicleRequestInFlight) return;
    NSString *routeIDs = [self visibleRouteIDs];
    if (!routeIDs.length) {
        [self clearVehicleAnnotations];
        return;
    }
    MKCoordinateRegion region = self.mapView.region;
    double north = region.center.latitude + region.span.latitudeDelta / 2.0;
    double south = region.center.latitude - region.span.latitudeDelta / 2.0;
    double east = region.center.longitude + region.span.longitudeDelta / 2.0;
    double west = region.center.longitude - region.span.longitudeDelta / 2.0;
    NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:
                                [STStore sharedStore].cityCode, @"city",
                                routeIDs, @"rids",
                                [NSNumber numberWithInteger:self.vehicleAnimationKey], @"curk",
                                [NSNumber numberWithInt:(int)(north * 1000000.0)], @"lat0",
                                [NSNumber numberWithInt:(int)(east * 1000000.0)], @"lng0",
                                [NSNumber numberWithInt:(int)(south * 1000000.0)], @"lat1",
                                [NSNumber numberWithInt:(int)(west * 1000000.0)], @"lng1",
                                @"14", @"zoom", nil];
    NSInteger generation = self.vehicleGeneration;
    self.vehicleRequestInFlight = YES;
    [[STAPIClient sharedClient] getVehiclePath:@"getVehicleAnimations.php" parameters:parameters completion:^(id object, NSError *error) {
        if (generation != self.vehicleGeneration) return;
        self.vehicleRequestInFlight = NO;
        if (![object isKindOfClass:[NSArray class]]) return;
        [self applyVehiclePayload:(NSArray *)object atTime:CACurrentMediaTime()];
    }];
}

- (NSArray *)routesMatchingRoute:(NSDictionary *)selectedRoute {
    NSString *type = STString([selectedRoute objectForKey:@"type"]);
    NSString *number = STString([selectedRoute objectForKey:@"number"]);
    return [[STStore sharedStore].routes filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id route, NSDictionary *bindings) {
        return [STString([route objectForKey:@"type"]) isEqualToString:type]
            && [STString([route objectForKey:@"number"]) isEqualToString:number];
    }]];
}

- (void)loadCurrentRouteAtIndex:(NSUInteger)index generation:(NSInteger)generation visibleRect:(MKMapRect)visibleRect {
    if (generation != self.routeLoadGeneration) return;
    if (index >= self.currentRoutes.count) {
        if (!MKMapRectIsNull(visibleRect)) {
            [self.mapView setVisibleMapRect:visibleRect edgePadding:UIEdgeInsetsMake(45, 25, 92, 25) animated:YES];
        }
        NSDictionary *route = [self.currentRoutes objectAtIndex:0];
        self.statusLabel.text = [NSString stringWithFormat:@"%@ №%@ · линий: %lu",
                                 STTransportName(STString([route objectForKey:@"type"])),
                                 STString([route objectForKey:@"number"]), (unsigned long)self.currentRoutes.count];
        [UIView animateWithDuration:0.3 delay:1.2 options:0 animations:^{ self.statusLabel.alpha = 0.0; } completion:nil];
        [self refreshVehicles];
        return;
    }
    NSDictionary *route = [self.currentRoutes objectAtIndex:index];
    NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:
                                [STStore sharedStore].cityCode, @"city",
                                [NSNumber numberWithInteger:STInteger([route objectForKey:@"id"])], @"id", nil];
    [[STAPIClient sharedClient] getPath:@"getRouteNodes.php" parameters:parameters completion:^(id object, NSError *error) {
        if (generation != self.routeLoadGeneration) return;
        MKMapRect combined = visibleRect;
        if ([object isKindOfClass:[NSArray class]] && [object count] >= 2) {
            NSUInteger count = [object count];
            CLLocationCoordinate2D *coordinates = malloc(sizeof(CLLocationCoordinate2D) * count);
            NSUInteger pointIndex;
            for (pointIndex = 0; pointIndex < count; pointIndex++) {
                NSDictionary *node = [object objectAtIndex:pointIndex];
                coordinates[pointIndex] = CLLocationCoordinate2DMake(STCoordinateValue([node objectForKey:@"lat"]), STCoordinateValue([node objectForKey:@"lon"]));
            }
            MKPolyline *overlay = [MKPolyline polylineWithCoordinates:coordinates count:count];
            free(coordinates);
            [self.routeOverlays addObject:overlay];
            [self.mapView addOverlay:overlay];
            combined = MKMapRectIsNull(combined) ? overlay.boundingMapRect : MKMapRectUnion(combined, overlay.boundingMapRect);
        }
        [self loadCurrentRouteAtIndex:index + 1 generation:generation visibleRect:combined];
    }];
}

- (void)routesViewController:(STRoutesViewController *)controller selectedRoute:(NSDictionary *)route {
    [self clearDisplayedRoutes];
    self.currentRoutes = [self routesMatchingRoute:route];
    [self updateRouteCloseButton];
    [self clearVehicleAnnotations];
    self.statusLabel.alpha = 1.0;
    self.statusLabel.text = [NSString stringWithFormat:@"Загрузка всех линий №%@…", STString([route objectForKey:@"number"])];
    [self loadCurrentRouteAtIndex:0 generation:self.routeLoadGeneration visibleRect:MKMapRectNull];
}

- (void)routesViewControllerShowAllRoutes:(STRoutesViewController *)controller {
    [self centerOnSelectedCityAnimated:YES];
    self.statusLabel.alpha = 1.0;
    self.statusLabel.text = @"Все маршруты возвращены на карту";
    [UIView animateWithDuration:0.3 delay:1.0 options:0 animations:^{ self.statusLabel.alpha = 0.0; } completion:nil];
    [self refreshVehicles];
}

- (UIImage *)smallStationImageForType:(NSInteger)type {
    static UIImage *busImage = nil;
    static UIImage *tramImage = nil;
    UIImage **cached = type == 0 ? &busImage : &tramImage;
    if (!*cached) {
        UIImage *source = [UIImage imageNamed:(type == 0 ? @"station-bus.png" : @"station-tram.png")];
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(20, 20), NO, 0.0);
        [source drawInRect:CGRectMake(0, 0, 20, 20)];
        *cached = [UIGraphicsGetImageFromCurrentImageContext() retain];
        UIGraphicsEndImageContext();
    }
    return *cached;
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
    if ([annotation isKindOfClass:[MKUserLocation class]]) {
        static NSString *positionID = @"MyPositionAnnotation";
        MKAnnotationView *positionView = [mapView dequeueReusableAnnotationViewWithIdentifier:positionID];
        if (!positionView) {
            positionView = [[[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:positionID] autorelease];
            positionView.canShowCallout = NO;
        }
        positionView.annotation = annotation;
        positionView.image = [UIImage imageNamed:@"navposition.png"];
        return positionView;
    }
    STAnnotation *item = (STAnnotation *)annotation;
    if (item.kind == STAnnotationKindVehicle) {
        static NSString *vehicleID = @"VehicleAnnotation";
        STVehicleAnnotationView *view = (STVehicleAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:vehicleID];
        if (!view) {
            view = [[[STVehicleAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:vehicleID] autorelease];
        }
        view.annotation = annotation;
        [view configureWithVehicle:item.data showFeatureFlag:[self vehicleFlagsEnabled]];
        return view;
    }
    static NSString *stationID = @"StationAnnotation";
    MKAnnotationView *view = [mapView dequeueReusableAnnotationViewWithIdentifier:stationID];
    if (!view) {
        view = [[[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:stationID] autorelease];
        view.canShowCallout = YES;
        view.centerOffset = CGPointMake(0, -8);
        view.rightCalloutAccessoryView = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
    }
    view.annotation = annotation;
    view.image = [self smallStationImageForType:STInteger([item.data objectForKey:@"type"])];
    return view;
}

- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control {
    STAnnotation *annotation = (STAnnotation *)view.annotation;
    if (annotation.kind != STAnnotationKindStation) return;
    STForecastViewController *forecast = [[[STForecastViewController alloc] initWithStation:annotation.data] autorelease];
    [self.navigationController pushViewController:forecast animated:YES];
}

- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view {
    if (![view.annotation isKindOfClass:[STAnnotation class]]) return;
    STAnnotation *annotation = (STAnnotation *)view.annotation;
    if (annotation.kind != STAnnotationKindVehicle || self.navigationController.topViewController != self) return;
    [mapView deselectAnnotation:annotation animated:NO];
    STVehicleScheduleViewController *schedule = [[[STVehicleScheduleViewController alloc] initWithVehicle:annotation.data] autorelease];
    [self.navigationController pushViewController:schedule animated:YES];
}

- (void)mapView:(MKMapView *)mapView regionWillChangeAnimated:(BOOL)animated {
    // The model coordinates already point at the newest server positions.
    // Cancel visual paths while the map itself is being transformed.
    self.snapNextVehicleUpdate = YES;
    for (STAnnotation *annotation in self.vehicleAnnotations) {
        MKAnnotationView *view = [mapView viewForAnnotation:annotation];
        CLLocationCoordinate2D visibleCoordinate = [self visualCoordinateForAnnotation:annotation];
        [view.layer removeAnimationForKey:@"STVehicleMovement"];
        annotation.coordinate = visibleCoordinate;
    }
}

- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(refreshMapForChangedRegion) object:nil];
    [self performSelector:@selector(refreshMapForChangedRegion) withObject:nil afterDelay:0.25];
}

- (void)refreshMapForChangedRegion {
    [self reloadStationAnnotations];
    self.vehicleGeneration++;
    self.vehicleRequestInFlight = NO;
    self.vehicleAnimationKey = 0;
    self.snapNextVehicleUpdate = YES;
    [self refreshVehicles];
}

- (MKOverlayView *)mapView:(MKMapView *)mapView viewForOverlay:(id<MKOverlay>)overlay {
    if ([overlay isKindOfClass:[STDarkMapOverlay class]]) {
        return [[[STDarkMapOverlayView alloc] initWithOverlay:overlay] autorelease];
    }
    if ([overlay isKindOfClass:[MKPolyline class]]) {
        MKPolylineView *view = [[[MKPolylineView alloc] initWithPolyline:(MKPolyline *)overlay] autorelease];
        view.strokeColor = [UIColor colorWithRed:0.08 green:0.45 blue:0.9 alpha:0.9];
        view.lineWidth = 5.0;
        return view;
    }
    return nil;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    _mapView.delegate = nil;
    _locationManager.delegate = nil;
    [_mapView release];
    [_stationAnnotations release];
    [_vehicleAnnotations release];
    [_vehicleAnnotationsByID release];
    [_routeOverlays release];
    [_darkMapOverlay release];
    [_currentRoutes release];
    [_locationManager release];
    [_currentLocation release];
    [_statusLabel release];
    [_stationToggleButton release];
    [_vehicleFlagsButton release];
    [_bottomTabBar release];
    [_bottomTabButtons release];
    [_routeCloseButton release];
    [_vehicleTimer invalidate];
    [_vehicleTimer release];
    [super dealloc];
}

@end
