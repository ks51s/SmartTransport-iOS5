#import "STVehicleAnnotationView.h"

@implementation STVehicleAnnotationView

@synthesize routeNumber = _routeNumber;
@synthesize transportType = _transportType;
@synthesize direction = _direction;

- (id)initWithAnnotation:(id<MKAnnotation>)annotation reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithAnnotation:annotation reuseIdentifier:reuseIdentifier];
    if (self) {
        self.frame = CGRectMake(0, 0, 44, 44);
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.canShowCallout = NO;
        self.centerOffset = CGPointZero;
    }
    return self;
}

- (UIColor *)markerColor {
    // Original SmartTransport transport colors.
    if ([self.transportType isEqualToString:@"Т"] || [self.transportType isEqualToString:@"Тб"]) {
        return [UIColor colorWithRed:0.00 green:0.667 blue:0.741 alpha:1.0];
    }
    if ([self.transportType isEqualToString:@"Тр"] || [self.transportType isEqualToString:@"Тм"] || [self.transportType isEqualToString:@"Мор"]) {
        return [UIColor colorWithRed:0.204 green:0.659 blue:0.325 alpha:1.0];
    }
    if ([self.transportType isEqualToString:@"М"] || [self.transportType isEqualToString:@"Мт"]) {
        return [UIColor colorWithRed:0.988 green:0.694 blue:0.00 alpha:1.0];
    }
    return [UIColor colorWithRed:1.00 green:0.153 blue:0.110 alpha:1.0];
}

- (void)configureWithVehicle:(NSDictionary *)vehicle {
    self.routeNumber = STString([vehicle objectForKey:@"rnum"]);
    self.transportType = STString([vehicle objectForKey:@"rtype"]);
    self.direction = (CGFloat)STDouble([vehicle objectForKey:@"dir"]);
    self.accessibilityLabel = [NSString stringWithFormat:@"%@ №%@, следует до %@",
                               STTransportName(self.transportType), self.routeNumber,
                               STString([vehicle objectForKey:@"_destination"])];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    CGContextSetShadowWithColor(context, CGSizeMake(0, 1), 1.5, [UIColor colorWithWhite:0 alpha:0.42].CGColor);

    CGPoint center = CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
    CGFloat radius = 13.5;
    CGFloat radians = (self.direction - 90.0) * (CGFloat)M_PI / 180.0;
    CGFloat dx = cosf(radians);
    CGFloat dy = sinf(radians);
    CGFloat px = -dy;
    CGFloat py = dx;
    CGPoint base = CGPointMake(center.x + dx * (radius - 4.0), center.y + dy * (radius - 4.0));
    CGPoint tip = CGPointMake(center.x + dx * (radius + 7.0), center.y + dy * (radius + 7.0));
    CGPoint left = CGPointMake(base.x + px * 7.0, base.y + py * 7.0);
    CGPoint right = CGPointMake(base.x - px * 7.0, base.y - py * 7.0);

    UIColor *color = [self markerColor];
    [color setFill];
    [[UIColor colorWithWhite:0.18 alpha:0.72] setStroke];
    CGContextSetLineWidth(context, 1.25);
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, tip.x, tip.y);
    CGContextAddLineToPoint(context, left.x, left.y);
    CGContextAddLineToPoint(context, right.x, right.y);
    CGContextClosePath(context);
    CGContextDrawPath(context, kCGPathFillStroke);

    CGContextFillEllipseInRect(context, CGRectMake(center.x - radius, center.y - radius, radius * 2.0, radius * 2.0));
    CGContextStrokeEllipseInRect(context, CGRectMake(center.x - radius, center.y - radius, radius * 2.0, radius * 2.0));
    CGContextRestoreGState(context);

    CGFloat fontSize = self.routeNumber.length >= 4 ? 9.0 : (self.routeNumber.length == 3 ? 10.5 : 13.0);
    [[UIColor colorWithWhite:0.05 alpha:1.0] setFill];
    [self.routeNumber drawInRect:CGRectMake(center.x - radius + 1.0, center.y - 8.0, radius * 2.0 - 2.0, 17.0)
                         withFont:[UIFont boldSystemFontOfSize:fontSize]
                    lineBreakMode:NSLineBreakByClipping
                        alignment:NSTextAlignmentCenter];
}

- (void)dealloc {
    [_routeNumber release];
    [_transportType release];
    [super dealloc];
}

@end
