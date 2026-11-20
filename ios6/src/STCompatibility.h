#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>

#define STStoreDidReloadNotification @"STStoreDidReloadNotification"
#define STStoreCityDidChangeNotification @"STStoreCityDidChangeNotification"
#define STMapTypeDidChangeNotification @"STMapTypeDidChangeNotification"
#define STStationVisibilityDidChangeNotification @"STStationVisibilityDidChangeNotification"
#define STStationSpacingDidChangeNotification @"STStationSpacingDidChangeNotification"
#define STVisibleRoutesDidChangeNotification @"STVisibleRoutesDidChangeNotification"
#define STThemeDidChangeNotification @"STThemeDidChangeNotification"

static inline NSString *STString(id value) {
    if (value == nil || value == [NSNull null]) return @"";
    if ([value isKindOfClass:[NSString class]]) return value;
    return [value description];
}

static inline NSInteger STInteger(id value) {
    return (value == nil || value == [NSNull null]) ? 0 : [value integerValue];
}

static inline double STDouble(id value) {
    return (value == nil || value == [NSNull null]) ? 0.0 : [value doubleValue];
}

static inline double STCoordinateValue(id value) {
    double result = STDouble(value);
    if (fabs(result) > 180.0) result /= 1000000.0;
    return result;
}

static inline UIColor *STTintColor(void) {
    return [UIColor colorWithRed:0.12 green:0.48 blue:0.76 alpha:1.0];
}

static inline NSString *STTransportName(NSString *type) {
    if ([type isEqualToString:@"А"] || [type isEqualToString:@"Ав"]) return @"Автобус";
    if ([type isEqualToString:@"Т"] || [type isEqualToString:@"Тб"]) return @"Троллейбус";
    if ([type isEqualToString:@"Тр"] || [type isEqualToString:@"Тм"]) return @"Трамвай";
    if ([type isEqualToString:@"М"] || [type isEqualToString:@"Мт"]) return @"Маршрутное такси";
    if ([type isEqualToString:@"Мор"]) return @"Водный транспорт";
    return type.length ? type : @"Транспорт";
}

static inline NSString *STStripHTML(NSString *source) {
    if (!source.length) return @"";
    NSMutableString *result = [NSMutableString stringWithCapacity:source.length];
    BOOL inside = NO;
    NSUInteger i;
    for (i = 0; i < source.length; i++) {
        unichar c = [source characterAtIndex:i];
        if (c == '<') inside = YES;
        else if (c == '>') inside = NO;
        else if (!inside) [result appendFormat:@"%C", c];
    }
    [result replaceOccurrencesOfString:@"&nbsp;" withString:@" " options:0 range:NSMakeRange(0, result.length)];
    [result replaceOccurrencesOfString:@"&rarr;" withString:@"→" options:0 range:NSMakeRange(0, result.length)];
    return result;
}

static inline void STShowError(UIViewController *controller, NSString *message) {
    UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:@"Умный транспорт"
                                                     message:message.length ? message : @"Не удалось загрузить данные"
                                                    delegate:nil
                                           cancelButtonTitle:@"ОК"
                                           otherButtonTitles:nil] autorelease];
    [alert show];
}
