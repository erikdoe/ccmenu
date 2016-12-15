
#import <Cocoa/Cocoa.h>

typedef enum {
	CCMUnknownServer = -1,
	CCMCruiseControlDashboard = 0,
	CCMCruiseControlClassic = 1,
    CCMCruiseControlDotNetServer = 2,   // CC.rb uses the same URL
    CCMHudsonServer = 3, // Jenkins, Travis use same URL
    CCMXcodeBot = 4 // Xcode Bot
} CCMServerType;

typedef enum {
    CCMDetectServer = -1,
    CCMUseGivenURL = 0
} CCMServerURLHandling;


@interface NSString(CCMAdditions)

- (NSString *)stringByAddingSchemeIfNecessary;
- (NSString *)stringByReplacingCredentials:(NSString *)credentials;
- (NSString *)user;
- (NSString *)host;

- (CCMServerType)serverType;
- (NSString *)completeURLForServerType:(CCMServerType)serverType;
- (NSArray *)completeURLForAllServerTypes;
- (NSString *)stringByRemovingServerReportFileName;

@end
