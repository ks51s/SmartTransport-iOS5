#import "STCompatibility.h"

typedef void (^STAPICompletion)(id object, NSError *error);

@interface STAPIClient : NSObject

+ (STAPIClient *)sharedClient;
- (void)getPath:(NSString *)path parameters:(NSDictionary *)parameters completion:(STAPICompletion)completion;
- (void)getVehiclePath:(NSString *)path parameters:(NSDictionary *)parameters completion:(STAPICompletion)completion;
- (NSString *)mobileIdentifier;
- (NSString *)installIdentifier;

@end
