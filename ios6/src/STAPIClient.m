#import "STAPIClient.h"
#import <CommonCrypto/CommonCryptor.h>

@implementation STAPIClient

+ (STAPIClient *)sharedClient {
    static STAPIClient *client = nil;
    if (client == nil) client = [[STAPIClient alloc] init];
    return client;
}

- (id)init {
    self = [super init];
    if (self) {
        [self mobileIdentifier];
        [self installIdentifier];
        if (![[NSUserDefaults standardUserDefaults] boolForKey:@"STInstallRegistered"]) {
            NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [self installIdentifier], @"is",
                                    [self mobileIdentifier], @"id", nil];
            [self getPath:@"addStat.php" parameters:params completion:^(id object, NSError *error) {
                if (!error) {
                    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"STInstallRegistered"];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                }
            }];
        }
    }
    return self;
}

- (NSString *)randomStringWithLength:(NSUInteger)length {
    static NSString *alphabet = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    NSMutableString *result = [NSMutableString stringWithCapacity:length];
    NSUInteger i;
    for (i = 0; i < length; i++) {
        [result appendFormat:@"%C", [alphabet characterAtIndex:arc4random_uniform((u_int32_t)alphabet.length)]];
    }
    return result;
}

- (NSString *)mobileIdentifier {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *identifier = [defaults stringForKey:@"STMobileIdentifier"];
    if (!identifier.length) {
        CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
        NSString *uuidString = [(NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuid) autorelease];
        CFRelease(uuid);
        identifier = [[[uuidString stringByReplacingOccurrencesOfString:@"-" withString:@""] lowercaseString] substringToIndex:16];
        [defaults setObject:identifier forKey:@"STMobileIdentifier"];
        [defaults synchronize];
    }
    return identifier;
}

- (NSString *)installIdentifier {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *identifier = [defaults stringForKey:@"STInstallIdentifier"];
    if (!identifier.length) {
        identifier = [self randomStringWithLength:8];
        [defaults setObject:identifier forKey:@"STInstallIdentifier"];
        [defaults synchronize];
    }
    return identifier;
}

- (NSString *)escaped:(id)value {
    NSString *string = STString(value);
    return [string stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
}

- (NSURL *)URLForPath:(NSString *)path parameters:(NSDictionary *)parameters {
    NSMutableString *url = [NSMutableString stringWithFormat:@"http://api9.bus62.ru/%@", path];
    if (parameters.count) {
        [url appendString:@"?"];
        NSArray *keys = [[parameters allKeys] sortedArrayUsingSelector:@selector(compare:)];
        NSUInteger index;
        for (index = 0; index < keys.count; index++) {
            NSString *key = [keys objectAtIndex:index];
            if (index) [url appendString:@"&"];
            [url appendFormat:@"%@=%@", [self escaped:key], [self escaped:[parameters objectForKey:key]]];
        }
    }
    return [NSURL URLWithString:url];
}

- (NSString *)authenticationToken {
    NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
    [formatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"] autorelease]];
    [formatter setCalendar:[[[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar] autorelease]];
    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    [formatter setDateFormat:@"ss:mm:HH yyyy-MM-dd"];
    // This is the wire format used by the original ARM JNI bridge. Its
    // deliberately reversed UTC time and separator must remain byte exact.
    NSString *plainString = [NSString stringWithFormat:@"%@|12345", [formatter stringFromDate:[NSDate date]]];
    while (plainString.length < 32) plainString = [plainString stringByAppendingString:@" "];
    NSData *plain = [[plainString substringToIndex:32] dataUsingEncoding:NSUTF8StringEncoding];
    const unsigned char key[16] = "12jIaCP0K8nK0xHN";
    const unsigned char iv[16] = "0BAQEFAASB9TCB8g";
    unsigned char output[32];
    size_t moved = 0;
    CCCryptorStatus status = CCCrypt(kCCEncrypt, kCCAlgorithmAES128, 0, key, sizeof(key), iv,
                                     [plain bytes], [plain length], output, sizeof(output), &moved);
    if (status != kCCSuccess || moved != sizeof(output)) return @"";
    NSMutableString *hex = [NSMutableString stringWithCapacity:64];
    NSUInteger i;
    for (i = 0; i < moved; i++) [hex appendFormat:@"%02x", output[i]];
    return hex;
}

- (void)performPath:(NSString *)path parameters:(NSDictionary *)parameters vehicle:(BOOL)vehicle completion:(STAPICompletion)completion {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[self URLForPath:path parameters:parameters]
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:30.0];
    [request setHTTPMethod:@"GET"];
    NSString *agent = vehicle
        ? [NSString stringWithFormat:@"okhttp_%@_%@", [self mobileIdentifier], [self installIdentifier]]
        : [NSString stringWithFormat:@"okhttp_%@", [self mobileIdentifier]];
    [request setValue:agent forHTTPHeaderField:@"User-Agent"];
    if (vehicle) [request setValue:[self authenticationToken] forHTTPHeaderField:@"Content-MD5-Hash"];

    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        NSError *error = connectionError;
        NSInteger status = [(NSHTTPURLResponse *)response statusCode];
        id object = nil;
        if (!error && (status < 200 || status >= 300)) {
            error = [NSError errorWithDomain:@"SmartTransportAPI" code:status
                                     userInfo:[NSDictionary dictionaryWithObject:@"Сервер отклонил запрос" forKey:NSLocalizedDescriptionKey]];
        }
        if (!error && data.length) {
            object = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
        }
        if (!error && !object && status >= 200 && status < 300) object = [NSDictionary dictionary];
        if (completion) completion(object, error);
    }];
}

- (void)getPath:(NSString *)path parameters:(NSDictionary *)parameters completion:(STAPICompletion)completion {
    [self performPath:path parameters:parameters vehicle:NO completion:completion];
}

- (void)getVehiclePath:(NSString *)path parameters:(NSDictionary *)parameters completion:(STAPICompletion)completion {
    [self performPath:path parameters:parameters vehicle:YES completion:completion];
}

@end
