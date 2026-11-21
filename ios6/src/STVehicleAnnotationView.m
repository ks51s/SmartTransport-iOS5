#import "STVehicleAnnotationView.h"

@implementation STVehicleAnnotationView

@synthesize routeNumber = _routeNumber;
@synthesize transportType = _transportType;
@synthesize featureText = _featureText;
@synthesize direction = _direction;
@synthesize showFeatureFlag = _showFeatureFlag;

- (id)initWithAnnotation:(id<MKAnnotation>)annotation reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithAnnotation:annotation reuseIdentifier:reuseIdentifier];
    if (self) {
        self.frame = CGRectMake(0, 0, 88, 52);
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.canShowCallout = NO;
        // Marker center is x=24; remaining width holds the optional flag.
        self.centerOffset = CGPointMake(20, 0);
    }
    return self;
}

- (NSString *)markerImageName {
    if ([self.transportType isEqualToString:@"Т"] || [self.transportType isEqualToString:@"Тб"]) return @"vehicle-trolley.png";
    if ([self.transportType isEqualToString:@"Тр"] || [self.transportType isEqualToString:@"Тм"] || [self.transportType isEqualToString:@"Мор"]) return @"vehicle-tram.png";
    if ([self.transportType isEqualToString:@"М"] || [self.transportType isEqualToString:@"Мт"]) return @"vehicle-minibus.png";
    return @"vehicle-bus.png";
}

- (void)configureWithVehicle:(NSDictionary *)vehicle {
    [self configureWithVehicle:vehicle showFeatureFlag:NO];
}

- (void)configureWithVehicle:(NSDictionary *)vehicle showFeatureFlag:(BOOL)showFeatureFlag {
    self.routeNumber = STString([vehicle objectForKey:@"rnum"]);
    self.transportType = STString([vehicle objectForKey:@"rtype"]);
    self.direction = (CGFloat)STDouble([vehicle objectForKey:@"dir"]);
    self.showFeatureFlag = showFeatureFlag;

    long long flags = [STString([vehicle objectForKey:@"flags"]) longLongValue];
    NSMutableArray *features = [NSMutableArray array];
    NSMutableArray *spoken = [NSMutableArray array];
    if ([STString([vehicle objectForKey:@"low_floor"]) isEqualToString:@"1"] || (flags & 1LL)) {
        [features addObject:@"♿"];
        [spoken addObject:@"низкопольный"];
    }
    if ([STString([vehicle objectForKey:@"wifi"]) isEqualToString:@"1"] || (flags & 4LL)) {
        [features addObject:@"Wi"];
        [spoken addObject:@"Wi-Fi"];
    }
    if (flags & 16LL) {
        [features addObject:@"❄"];
        [spoken addObject:@"кондиционер"];
    }
    if (flags & 32LL) {
        [features addObject:@"К"];
        [spoken addObject:@"место для коляски"];
    }
    self.featureText = [features componentsJoinedByString:@" "];
    NSString *featuresDescription = spoken.count
        ? [NSString stringWithFormat:@", %@", [spoken componentsJoinedByString:@", "]] : @"";
    self.accessibilityLabel = [NSString stringWithFormat:@"%@ №%@, следует до %@%@",
                               STTransportName(self.transportType), self.routeNumber,
                               STString([vehicle objectForKey:@"_destination"]), featuresDescription];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGPoint markerCenter = CGPointMake(24.0, CGRectGetMidY(rect));

    CGContextSaveGState(context);
    CGContextTranslateCTM(context, markerCenter.x, markerCenter.y);
    // Original marker points upward, while API direction uses compass degrees.
    CGContextRotateCTM(context, self.direction * (CGFloat)M_PI / 180.0);
    [[UIImage imageNamed:[self markerImageName]] drawInRect:CGRectMake(-22.0, -22.0, 44.0, 44.0)];
    CGContextRestoreGState(context);

    CGFloat fontSize = self.routeNumber.length >= 4 ? 9.0 : (self.routeNumber.length == 3 ? 10.5 : 13.0);
    [[UIColor colorWithWhite:0.05 alpha:1.0] setFill];
    [self.routeNumber drawInRect:CGRectMake(markerCenter.x - 13.0, markerCenter.y - 8.0, 26.0, 17.0)
                         withFont:[UIFont boldSystemFontOfSize:fontSize]
                    lineBreakMode:NSLineBreakByClipping
                        alignment:NSTextAlignmentCenter];

    if (self.showFeatureFlag && self.featureText.length) {
        CGFloat width = MIN(42.0, MAX(24.0, self.featureText.length * 7.0 + 8.0));
        CGRect flagRect = CGRectMake(39.0, 7.0, width, 20.0);
        UIBezierPath *flag = [UIBezierPath bezierPathWithRoundedRect:flagRect cornerRadius:3.0];
        [[UIColor colorWithWhite:1.0 alpha:0.94] setFill];
        [[UIColor colorWithWhite:0.18 alpha:0.85] setStroke];
        flag.lineWidth = 1.0;
        [flag fill];
        [flag stroke];

        CGContextBeginPath(context);
        CGContextMoveToPoint(context, 39.0, 11.0);
        CGContextAddLineToPoint(context, 34.0, 15.0);
        CGContextAddLineToPoint(context, 39.0, 19.0);
        CGContextClosePath(context);
        CGContextDrawPath(context, kCGPathFillStroke);

        [[UIColor colorWithWhite:0.08 alpha:1.0] setFill];
        [self.featureText drawInRect:CGRectInset(flagRect, 3.0, 3.0)
                            withFont:[UIFont boldSystemFontOfSize:9.0]
                       lineBreakMode:NSLineBreakByClipping
                           alignment:NSTextAlignmentCenter];
    }
}

- (void)dealloc {
    [_routeNumber release];
    [_transportType release];
    [_featureText release];
    [super dealloc];
}

@end
