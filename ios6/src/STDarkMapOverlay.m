#import "STDarkMapOverlay.h"

@implementation STDarkMapOverlay

- (CLLocationCoordinate2D)coordinate { return CLLocationCoordinate2DMake(0.0, 0.0); }
- (MKMapRect)boundingMapRect { return MKMapRectWorld; }

@end

@implementation STDarkMapOverlayView

- (void)drawMapRect:(MKMapRect)mapRect zoomScale:(MKZoomScale)zoomScale inContext:(CGContextRef)context {
    CGRect rect = [self rectForMapRect:mapRect];
    CGContextSetFillColorWithColor(context, [UIColor colorWithRed:0.015 green:0.025 blue:0.04 alpha:0.48].CGColor);
    CGContextFillRect(context, rect);
}

@end
