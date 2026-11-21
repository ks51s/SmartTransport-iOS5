#import "STCompatibility.h"

@interface STVehicleAnnotationView : MKAnnotationView

@property(nonatomic, copy) NSString *routeNumber;
@property(nonatomic, copy) NSString *transportType;
@property(nonatomic, copy) NSString *featureText;
@property(nonatomic, assign) CGFloat direction;
@property(nonatomic, assign) BOOL showFeatureFlag;

- (void)configureWithVehicle:(NSDictionary *)vehicle;
- (void)configureWithVehicle:(NSDictionary *)vehicle showFeatureFlag:(BOOL)showFeatureFlag;

@end
