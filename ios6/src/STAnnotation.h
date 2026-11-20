#import "STCompatibility.h"

typedef enum {
    STAnnotationKindStation = 0,
    STAnnotationKindVehicle = 1
} STAnnotationKind;

@interface STAnnotation : NSObject <MKAnnotation>

@property(nonatomic, assign) CLLocationCoordinate2D coordinate;
@property(nonatomic, copy) NSString *title;
@property(nonatomic, copy) NSString *subtitle;
@property(nonatomic, retain) NSDictionary *data;
@property(nonatomic, assign) STAnnotationKind kind;
@property(nonatomic, assign) CLLocationCoordinate2D movementOrigin;
@property(nonatomic, retain) NSArray *movementPath;
@property(nonatomic, retain) NSArray *movementWeights;
@property(nonatomic, assign) NSTimeInterval movementStartedAt;
@property(nonatomic, assign) NSTimeInterval movementDuration;
@property(nonatomic, assign) NSTimeInterval lastSeenAt;

+ (STAnnotation *)annotationWithCoordinate:(CLLocationCoordinate2D)coordinate
                                     title:(NSString *)title
                                  subtitle:(NSString *)subtitle
                                      data:(NSDictionary *)data
                                      kind:(STAnnotationKind)kind;

- (void)beginMovementAlongPath:(NSArray *)path weights:(NSArray *)weights duration:(NSTimeInterval)duration atTime:(NSTimeInterval)time;
- (BOOL)updateMovementAtTime:(NSTimeInterval)time;
- (void)finishMovement;

@end
