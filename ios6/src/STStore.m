#import "STStore.h"
#import "STAPIClient.h"

@implementation STStore

@synthesize cities = _cities;
@synthesize routes = _routes;
@synthesize stations = _stations;
@synthesize cityCode = _cityCode;

+ (STStore *)sharedStore {
    static STStore *store = nil;
    if (store == nil) store = [[STStore alloc] init];
    return store;
}

- (id)init {
    self = [super init];
    if (self) {
        NSString *saved = [[NSUserDefaults standardUserDefaults] stringForKey:@"STCityCode"];
        self.cityCode = saved.length ? saved : @"ryazan";
        self.cities = [self cachedObjectNamed:@"cities"];
        self.routes = [self cachedObjectNamed:[NSString stringWithFormat:@"routes-%@", self.cityCode]];
        self.stations = [self cachedObjectNamed:[NSString stringWithFormat:@"stations-%@", self.cityCode]];
        if (![self.cities isKindOfClass:[NSArray class]]) self.cities = [NSArray array];
        if (![self.routes isKindOfClass:[NSArray class]]) self.routes = [NSArray array];
        if (![self.stations isKindOfClass:[NSArray class]]) self.stations = [NSArray array];
    }
    return self;
}

- (NSString *)cacheDirectory {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *directory = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"SmartTransport"];
    [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
    return directory;
}

- (NSString *)cachePathNamed:(NSString *)name {
    return [[self cacheDirectory] stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"json"]];
}

- (id)cachedObjectNamed:(NSString *)name {
    NSData *data = [NSData dataWithContentsOfFile:[self cachePathNamed:name]];
    if (!data.length) return nil;
    return [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:NULL];
}

- (void)cacheObject:(id)object named:(NSString *)name {
    if (!object || ![NSJSONSerialization isValidJSONObject:object]) return;
    NSData *data = [NSJSONSerialization dataWithJSONObject:object options:0 error:NULL];
    [data writeToFile:[self cachePathNamed:name] atomically:YES];
}

- (void)notifyReload {
    [[NSNotificationCenter defaultCenter] postNotificationName:STStoreDidReloadNotification object:self];
}

- (void)loadInitialData:(STStoreCompletion)completion {
    if (self.cities.count || self.routes.count || self.stations.count) [self notifyReload];
    [[STAPIClient sharedClient] getPath:@"getAllCities.php" parameters:nil completion:^(id object, NSError *error) {
        if ([object isKindOfClass:[NSArray class]]) {
            self.cities = object;
            [self cacheObject:object named:@"cities"];
        }
        [self loadCityDataWithCompletion:completion];
    }];
}

- (void)loadCityDataWithCompletion:(STStoreCompletion)completion {
    NSDictionary *parameter = [NSDictionary dictionaryWithObject:self.cityCode forKey:@"city"];
    [[STAPIClient sharedClient] getPath:@"getAllRoutes.php" parameters:parameter completion:^(id routeObject, NSError *routeError) {
        if ([routeObject isKindOfClass:[NSArray class]]) {
            self.routes = routeObject;
            [self cacheObject:routeObject named:[NSString stringWithFormat:@"routes-%@", self.cityCode]];
        }
        [[STAPIClient sharedClient] getPath:@"getAllStations.php" parameters:parameter completion:^(id stationObject, NSError *stationError) {
            if ([stationObject isKindOfClass:[NSArray class]]) {
                self.stations = stationObject;
                [self cacheObject:stationObject named:[NSString stringWithFormat:@"stations-%@", self.cityCode]];
            }
            [self notifyReload];
            if (completion) completion(stationError ? stationError : routeError);
        }];
    }];
}

- (void)selectCityCode:(NSString *)code completion:(STStoreCompletion)completion {
    if (!code.length) return;
    self.cityCode = code;
    [[NSUserDefaults standardUserDefaults] setObject:code forKey:@"STCityCode"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    self.routes = [self cachedObjectNamed:[NSString stringWithFormat:@"routes-%@", code]];
    self.stations = [self cachedObjectNamed:[NSString stringWithFormat:@"stations-%@", code]];
    if (![self.routes isKindOfClass:[NSArray class]]) self.routes = [NSArray array];
    if (![self.stations isKindOfClass:[NSArray class]]) self.stations = [NSArray array];
    [[NSNotificationCenter defaultCenter] postNotificationName:STStoreCityDidChangeNotification object:self];
    [self notifyReload];
    [self loadCityDataWithCompletion:completion];
}

- (NSDictionary *)selectedCity {
    for (NSDictionary *city in self.cities) {
        if ([STString([city objectForKey:@"code"]) isEqualToString:self.cityCode]) return city;
    }
    return nil;
}

- (NSDictionary *)stationWithID:(NSInteger)identifier {
    for (NSDictionary *station in self.stations) {
        if (STInteger([station objectForKey:@"id"]) == identifier) return station;
    }
    return nil;
}

- (NSDictionary *)routeWithID:(NSInteger)identifier {
    for (NSDictionary *route in self.routes) {
        if (STInteger([route objectForKey:@"id"]) == identifier) return route;
    }
    return nil;
}

- (CLLocationCoordinate2D)selectedCityCoordinate {
    NSDictionary *city = [self selectedCity];
    if (!city) return CLLocationCoordinate2DMake(54.630633, 39.723978);
    return CLLocationCoordinate2DMake(STCoordinateValue([city objectForKey:@"lat"]), STCoordinateValue([city objectForKey:@"lon"]));
}

- (NSString *)preferenceKey:(NSString *)prefix {
    return [NSString stringWithFormat:@"%@-%@", prefix, self.cityCode];
}

- (NSMutableArray *)mutableIDsForKey:(NSString *)key {
    NSArray *saved = [[NSUserDefaults standardUserDefaults] arrayForKey:key];
    return saved ? [[saved mutableCopy] autorelease] : [NSMutableArray array];
}

- (BOOL)array:(NSArray *)array containsID:(NSInteger)identifier {
    return [array containsObject:[NSNumber numberWithInteger:identifier]];
}

- (void)toggleID:(NSInteger)identifier key:(NSString *)key maximum:(NSUInteger)maximum {
    NSMutableArray *values = [self mutableIDsForKey:key];
    NSNumber *number = [NSNumber numberWithInteger:identifier];
    if ([values containsObject:number]) [values removeObject:number];
    else [values insertObject:number atIndex:0];
    while (maximum && values.count > maximum) [values removeLastObject];
    [[NSUserDefaults standardUserDefaults] setObject:values forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSArray *)favoriteStationIDs { return [[NSUserDefaults standardUserDefaults] arrayForKey:[self preferenceKey:@"STFavoriteStations"]] ?: [NSArray array]; }
- (BOOL)isFavoriteStation:(NSInteger)identifier { return [self array:[self favoriteStationIDs] containsID:identifier]; }
- (void)toggleFavoriteStation:(NSInteger)identifier { [self toggleID:identifier key:[self preferenceKey:@"STFavoriteStations"] maximum:0]; }

- (NSArray *)recentStationIDs { return [[NSUserDefaults standardUserDefaults] arrayForKey:[self preferenceKey:@"STRecentStations"]] ?: [NSArray array]; }
- (void)addRecentStation:(NSInteger)identifier {
    NSString *key = [self preferenceKey:@"STRecentStations"];
    NSMutableArray *values = [self mutableIDsForKey:key];
    NSNumber *number = [NSNumber numberWithInteger:identifier];
    [values removeObject:number];
    [values insertObject:number atIndex:0];
    while (values.count > 10) [values removeLastObject];
    [[NSUserDefaults standardUserDefaults] setObject:values forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSArray *)favoriteRouteIDs { return [[NSUserDefaults standardUserDefaults] arrayForKey:[self preferenceKey:@"STFavoriteRoutes"]] ?: [NSArray array]; }
- (BOOL)isFavoriteRoute:(NSInteger)identifier { return [self array:[self favoriteRouteIDs] containsID:identifier]; }
- (void)toggleFavoriteRoute:(NSInteger)identifier { [self toggleID:identifier key:[self preferenceKey:@"STFavoriteRoutes"] maximum:0]; }

- (NSArray *)visibleRouteIDs {
    NSString *key = [self preferenceKey:@"STVisibleRoutes"];
    NSArray *saved = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    if (saved) return saved;
    NSMutableArray *all = [NSMutableArray arrayWithCapacity:self.routes.count];
    for (NSDictionary *route in self.routes) {
        [all addObject:[NSNumber numberWithInteger:STInteger([route objectForKey:@"id"])]];
    }
    return all;
}

- (void)setVisibleRouteIDs:(NSArray *)identifiers {
    [[NSUserDefaults standardUserDefaults] setObject:(identifiers ?: [NSArray array]) forKey:[self preferenceKey:@"STVisibleRoutes"]];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:STVisibleRoutesDidChangeNotification object:self];
}

- (void)showAllRoutes {
    NSMutableArray *all = [NSMutableArray arrayWithCapacity:self.routes.count];
    for (NSDictionary *route in self.routes) {
        [all addObject:[NSNumber numberWithInteger:STInteger([route objectForKey:@"id"])]];
    }
    [self setVisibleRouteIDs:all];
}

- (unsigned long long)cacheSizeBytes {
    unsigned long long total = 0;
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:[self cacheDirectory]];
    NSString *relative;
    while ((relative = [enumerator nextObject])) {
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[[self cacheDirectory] stringByAppendingPathComponent:relative] error:NULL];
        total += [[attributes objectForKey:NSFileSize] unsignedLongLongValue];
    }
    total += [[NSURLCache sharedURLCache] currentDiskUsage];
    return total;
}

- (void)clearCache {
    [[NSFileManager defaultManager] removeItemAtPath:[self cacheDirectory] error:NULL];
    [[NSFileManager defaultManager] createDirectoryAtPath:[self cacheDirectory] withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
}

- (void)dealloc {
    [_cities release];
    [_routes release];
    [_stations release];
    [_cityCode release];
    [super dealloc];
}

@end
