#import "STAnnotation.h"

@implementation STAnnotation

@synthesize coordinate = _coordinate;
@synthesize title = _title;
@synthesize subtitle = _subtitle;
@synthesize data = _data;
@synthesize kind = _kind;
@synthesize movementOrigin = _movementOrigin;
@synthesize movementPath = _movementPath;
@synthesize movementWeights = _movementWeights;
@synthesize movementStartedAt = _movementStartedAt;
@synthesize movementDuration = _movementDuration;
@synthesize lastSeenAt = _lastSeenAt;

+ (STAnnotation *)annotationWithCoordinate:(CLLocationCoordinate2D)coordinate title:(NSString *)title subtitle:(NSString *)subtitle data:(NSDictionary *)data kind:(STAnnotationKind)kind {
    STAnnotation *annotation = [[[STAnnotation alloc] init] autorelease];
    annotation.coordinate = coordinate;
    annotation.title = title;
    annotation.subtitle = subtitle;
    annotation.data = data;
    annotation.kind = kind;
    return annotation;
}

- (void)beginMovementAlongPath:(NSArray *)path weights:(NSArray *)weights duration:(NSTimeInterval)duration atTime:(NSTimeInterval)time {
    if (path.count == 0) return;
    self.movementOrigin = self.coordinate;
    self.movementPath = path;
    self.movementWeights = weights;
    self.movementStartedAt = time;
    self.movementDuration = MAX(0.1, duration);
}

- (BOOL)updateMovementAtTime:(NSTimeInterval)time {
    if (self.movementPath.count == 0) return NO;
    double progress = (time - self.movementStartedAt) / self.movementDuration;
    if (progress >= 1.0) {
        NSValue *last = [self.movementPath lastObject];
        CLLocationCoordinate2D coordinate;
        [last getValue:&coordinate];
        self.coordinate = coordinate;
        [self finishMovement];
        return NO;
    }
    if (progress < 0.0) progress = 0.0;

    double totalWeight = 0.0;
    NSUInteger index;
    for (index = 0; index < self.movementPath.count; index++) {
        double weight = index < self.movementWeights.count ? [[self.movementWeights objectAtIndex:index] doubleValue] : 1.0;
        totalWeight += MAX(0.01, weight);
    }
    double position = progress * totalWeight;
    double passed = 0.0;
    CLLocationCoordinate2D from = self.movementOrigin;
    for (index = 0; index < self.movementPath.count; index++) {
        CLLocationCoordinate2D to;
        [[self.movementPath objectAtIndex:index] getValue:&to];
        double weight = index < self.movementWeights.count ? [[self.movementWeights objectAtIndex:index] doubleValue] : 1.0;
        weight = MAX(0.01, weight);
        if (position <= passed + weight || index == self.movementPath.count - 1) {
            double local = MIN(1.0, MAX(0.0, (position - passed) / weight));
            CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(
                from.latitude + (to.latitude - from.latitude) * local,
                from.longitude + (to.longitude - from.longitude) * local);
            self.coordinate = coordinate;
            return YES;
        }
        passed += weight;
        from = to;
    }
    return YES;
}

- (void)finishMovement {
    self.movementPath = nil;
    self.movementWeights = nil;
}

- (void)dealloc {
    [_title release];
    [_subtitle release];
    [_data release];
    [_movementPath release];
    [_movementWeights release];
    [super dealloc];
}

@end
