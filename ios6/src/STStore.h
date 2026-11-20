#import "STCompatibility.h"

typedef void (^STStoreCompletion)(NSError *error);

@interface STStore : NSObject

@property(nonatomic, retain) NSArray *cities;
@property(nonatomic, retain) NSArray *routes;
@property(nonatomic, retain) NSArray *stations;
@property(nonatomic, copy) NSString *cityCode;

+ (STStore *)sharedStore;
- (void)loadInitialData:(STStoreCompletion)completion;
- (void)selectCityCode:(NSString *)code completion:(STStoreCompletion)completion;
- (NSDictionary *)selectedCity;
- (NSDictionary *)stationWithID:(NSInteger)identifier;
- (NSDictionary *)routeWithID:(NSInteger)identifier;
- (CLLocationCoordinate2D)selectedCityCoordinate;

- (BOOL)isFavoriteStation:(NSInteger)identifier;
- (void)toggleFavoriteStation:(NSInteger)identifier;
- (NSArray *)favoriteStationIDs;
- (void)addRecentStation:(NSInteger)identifier;
- (NSArray *)recentStationIDs;

- (BOOL)isFavoriteRoute:(NSInteger)identifier;
- (void)toggleFavoriteRoute:(NSInteger)identifier;
- (NSArray *)favoriteRouteIDs;

- (NSArray *)visibleRouteIDs;
- (void)setVisibleRouteIDs:(NSArray *)identifiers;
- (void)showAllRoutes;

- (void)clearCache;
- (unsigned long long)cacheSizeBytes;

@end
