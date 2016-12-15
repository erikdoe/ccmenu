
#import <XCTest/XCTest.h>
#import "NSString+CCMAdditions.h"


@interface NSString_CCMAddtionsTest : XCTestCase
{
}

@end


@implementation NSString_CCMAddtionsTest

- (void)testDetectsCruiseControlDashboardURLs
{
	CCMServerType type = [@"http://localhost/cctray.xml" serverType];
	XCTAssertEqual(CCMCruiseControlDashboard, type, @"Should have detected dashboard URL.");
}

- (void)testDetectsClassicCruiseControlURLs
{
	CCMServerType type = [@"http://localhost/xml" serverType];
	XCTAssertEqual(CCMCruiseControlClassic, type, @"Should have detected classic reporting app URL.");
}

- (void)testDetectsCruiseControlDotNetURLs
{
	CCMServerType type = [@"http://localhost/XmlStatusReport.aspx" serverType];
	XCTAssertEqual(CCMCruiseControlDotNetServer, type, @"Should have detected CC.NET URL.");
}

- (void)testDetectsHudsonURLs
{
	CCMServerType type = [@"http://localhost/cc.xml" serverType];
	XCTAssertEqual(CCMHudsonServer, type, @"Should have detected Hudson URL.");

}

- (void)testTreatsRandomXMLFileExtensionAsUnknown
{
	CCMServerType type = [@"http://localhost/foo.xml" serverType];
	XCTAssertEqual(CCMUnknownServer, type, @"Should have reported unknown server.");
}

- (void)testCompletesCruiseControlDashboardURL
{
	NSString *url = [@"http://localhost/" completeURLForServerType:CCMCruiseControlDashboard];
	XCTAssertEqualObjects(@"http://localhost/cctray.xml", url, @"Should have completed URL.");
}

- (void)testAddsMissingTrailingSlashWhenCompletingURLs
{
	NSString *url = [@"http://localhost" completeURLForServerType:CCMCruiseControlDashboard];
	XCTAssertEqualObjects(@"http://localhost/cctray.xml", url, @"Should have completed URL.");
}

- (void)testDoesNotAddFilenameWhenCorrectFilenameIsPresentWhenCompletingURLs
{
	NSString *url = [@"http://localhost/cctray.xml" completeURLForServerType:CCMCruiseControlDashboard];
	XCTAssertEqualObjects(@"http://localhost/cctray.xml", url, @"Should have completed URL.");
}

- (void)testAddsHTTPSchemeWhenCompletingURLs
{
	NSString *url = [@"localhost/cctray.xml" completeURLForServerType:CCMCruiseControlDashboard];
	XCTAssertEqualObjects(@"http://localhost/cctray.xml", url, @"Should have completed URL.");
}

- (void)testLeavesHTTPSSchemeWhenCompletingURLs
{
	NSString *url = [@"https://localhost/cctray.xml" completeURLForServerType:CCMCruiseControlDashboard];
	XCTAssertEqualObjects(@"https://localhost/cctray.xml", url, @"Should have kept HTTPS scheme.");
}

- (void)testCompletesCruiseControlClassicURLs
{
	NSString *url = [@"localhost" completeURLForServerType:CCMCruiseControlClassic];
	XCTAssertEqualObjects(@"http://localhost/xml", url, @"Should have completed URL.");
}

- (void)testCompletesCruiseControlDotNetURLs
{
	NSString *url = [@"localhost" completeURLForServerType:CCMCruiseControlDotNetServer];
	XCTAssertEqualObjects(@"http://localhost/XmlStatusReport.aspx", url, @"Should have completed URL.");
}

- (void)testCompletesHudsonURLs
{
	NSString *url = [@"localhost" completeURLForServerType:CCMHudsonServer];
	XCTAssertEqualObjects(@"http://localhost/cc.xml", url, @"Should have completed URL.");
}

- (void)testCompletesIntegrationServerURLs
{
	NSArray *urls = [@"http://localhost" completeURLForAllServerTypes];
	XCTAssertTrue([urls containsObject:@"http://localhost/cctray.xml"], @"Should have returned dashboard URL.");
	XCTAssertTrue([urls containsObject:@"http://localhost/dashboard/cctray.xml"], @"Should have returned alternate dashboard URL.");
	XCTAssertTrue([urls containsObject:@"http://localhost/go/cctray.xml"], @"Should have returned Go URL.");
	XCTAssertTrue([urls containsObject:@"http://localhost/xml"], @"Should have returned classic reporting URL.");
	XCTAssertTrue([urls containsObject:@"http://localhost/XmlStatusReport.aspx"], @"Should have returned CC.NET URL.");
	XCTAssertTrue([urls containsObject:@"http://localhost/ccnet/XmlStatusReport.aspx"], @"Should have returned alternate CC.NET URL.");
    XCTAssertTrue([urls containsObject:@"http://localhost/cc.xml"], @"Should have returned Hudson URL.");
    XCTAssertTrue([urls containsObject:@"http://localhost/hudson/cc.xml"], @"Should have returned alternate Hudson URL.");
    XCTAssertTrue([urls containsObject:@"http://localhost/api/bots"], @"Should have returned xcode bots URL.");
	XCTAssertEqual(9, [urls count], @"Should have returned only expected urls.");
}

- (void)testOnlyReturnsOneCompleteURLWhenURLWasComplete
{
	NSArray *urls = [@"localhost/XmlStatusReport.aspx" completeURLForAllServerTypes];
	XCTAssertTrue([urls containsObject:@"http://localhost/XmlStatusReport.aspx"], @"Should have returned complete URL.");
	XCTAssertEqual(1ul, [urls count], @"Should have returned only one urls.");
}

- (void)testRemovesDashboardFileNameIfPresent
{
	NSString *url = [@"http://localhost/cctray.xml" stringByRemovingServerReportFileName];
	XCTAssertEqualObjects(@"http://localhost/", url, @"Should have removed filename part from URL.");
}

- (void)testDetectsServerTypeEvenWhenQueryParameterIsPresent
{
    CCMServerType type = [@"https://api.travis-ci.com/repositories/company-name/project-name/cc.xml?token=secrettoken" serverType];
    XCTAssertEqual(CCMHudsonServer, type, @"Should have detected correct server type");
}

- (void)testLeavesQueryParametersIntactWhenCompletingURL
{
    NSString *url = [@"https://api.travis-ci.com/repositories/company-name/project-name?token=secrettoken" completeURLForServerType:CCMHudsonServer];
    XCTAssertEqualObjects(@"https://api.travis-ci.com/repositories/company-name/project-name/cc.xml?token=secrettoken", url, @"Should have added report filename in the correct place.");
}

- (void)testLeavesQueryParametersIntactWhenAskedToCompleteURLThatWasComplete
{
    NSString *url = [@"https://api.travis-ci.com/repositories/company-name/project-name/cc.xml?token=secrettoken" completeURLForServerType:CCMHudsonServer];
    XCTAssertEqualObjects(@"https://api.travis-ci.com/repositories/company-name/project-name/cc.xml?token=secrettoken", url, @"Should have added report filename in the correct place.");
}

- (void)testAddsUserToURLThatDoesNotHaveCredentials
{
    NSString *result = [@"http://hostname/path" stringByReplacingCredentials:@"user"];

    XCTAssertEqualObjects(@"http://user@hostname/path", result, @"Should have added user in correct place.");
}

- (void)testAddsUserToURLThatDoesNotHaveCredentialsOrScheme
{
    NSString *result = [@"hostname/path" stringByReplacingCredentials:@"user"];

    XCTAssertEqualObjects(@"http://user@hostname/path", result, @"Should have added user in correct place.");
}

- (void)testAddsUserToURLThatHasCredentials
{
    NSString *result = [@"https://old:password@hostname/path" stringByReplacingCredentials:@"new"];

    XCTAssertEqualObjects(@"https://new@hostname/path", result, @"Should have replaced existing credentials.");
}

- (void)testRemovesCredentialsForEmptyString
{
    NSString *result = [@"http://old:password@hostname/path" stringByReplacingCredentials:@""];

    XCTAssertEqualObjects(@"http://hostname/path", result, @"Should have removed existing credentials.");
}

- (void)testDoesNothingWhenURLDoesNotHaveCredentialsAndNewCredentialsAreEmpty
{
    NSString *result = [@"http://hostname/path" stringByReplacingCredentials:@""];

    XCTAssertEqualObjects(@"http://hostname/path", result, @"Should have stayed with no credentials.");
}

- (void)testCanReplaceCredentialsWhenExistingUserNameIsPrefixOfExistingScheme
{
    NSString *result = [@"http://ht@hostname/path" stringByReplacingCredentials:@"hto"];

    XCTAssertEqualObjects(@"http://hto@hostname/path", result, @"Should have replaced credentials.");
}

- (void)testEscapesCharactersForURL
{
    NSString *result = [@"http://foobar@hostname" stringByReplacingCredentials:@"a%:@b"];

    XCTAssertEqualObjects(@"http://a%25%3A%40b@hostname", result, @"Should have replaced credentials.");
}

- (void)testCanReplaceCredentialsWithMalformedPercentEscapes
{
    NSString *result = [@"http://foo%3@hostname" stringByReplacingCredentials:@"bar"];

    XCTAssertEqualObjects(@"http://bar@hostname", result, @"Should have replaced credentials.");
}

- (void)testReplacesMultipleUserMarkersInsideHostPortionOfUrl
{
    NSString *result = [@"http://foo@@hostname/path@4" stringByReplacingCredentials:@"bar"];

    XCTAssertEqualObjects(@"http://bar@hostname/path@4", result, @"Should have replaced credentials.");
}


@end
