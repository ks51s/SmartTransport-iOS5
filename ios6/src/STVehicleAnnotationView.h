#import "STCompatibility.h"

@interface STVehicleAnnotationView : MKAnnotationView

@property(nonatomic, copy) NSString *routeNumber;
@property(nonatomic, copy) NSString *transportType;
@property(nonatomic, assign) CGFloat direction;

- (void)configureWithVehicle:(NSDictionary *)vehicle;

@end
