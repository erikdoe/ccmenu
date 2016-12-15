
#import <SecurityInterface/SFCertificateTrustPanel.h>
#import "NSData+Extensions.h"
#import "CCMConnection.h"
#import "CCMXmlServerStatusReader.h"
#import "CCMBotsServerStatusReader.h"
#import "CCMKeychainHelper.h"
#import "NSString+EDExtensions.h"

@implementation CCMConnection

@synthesize feedURL;
@synthesize credential;
@synthesize delegate;

- (id)initWithFeedURL:(NSURL *)theFeedURL
{
    self = [super init];
    feedURL = [theFeedURL copy];
    return self;
}

- (id)initWithURLString:(NSString *)theFeedURL
{
    return [self initWithFeedURL:[NSURL URLWithString:theFeedURL]];
}

- (void)dealloc
{
    [feedURL release];
    [credential release];
    [receivedData release];
    [receivedResponse release];
    [nsurlConnection release]; // just in case
    [super dealloc];
}

- (BOOL)setUpCredential
{
    NSString *user = [feedURL user];
    if(user == nil)
        return NO;
    NSString *password = [CCMKeychainHelper passwordForURL:feedURL error:NULL];
    if(password == nil)
        return NO;
    [self setCredential:[NSURLCredential credentialWithUser:user password:password persistence:NSURLCredentialPersistenceForSession]];
    return YES;
}


- (void)setUpForNewRequest
{
    [receivedData release];
    receivedData = [[NSMutableData alloc] init];
    [receivedResponse release];
    receivedResponse = nil;
}

- (void)cleanUpAfterRequest
{
	[nsurlConnection release];
	nsurlConnection = nil;
}

- (void)requestServerStatus
{
    if(nsurlConnection != nil)
        return;
    [self setUpForNewRequest];
    nsurlConnection = [[NSURLConnection connectionWithRequest:[self createRequest] delegate:self] retain];
}

- (NSURLRequest *)createRequest
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:feedURL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:30.0];
    BOOL isInCloudbeesDomain = ([feedURL host] != nil) && ([[feedURL host] rangeOfString:@"cloudbees.com"].location != NSNotFound);
    if((useHudsonJenkinsAuthWorkaround || isInCloudbeesDomain) && ((credential != nil) || [self setUpCredential]))
        [self addBasicAuthToRequest:request];
    return request;
}

- (void)addBasicAuthToRequest:(NSMutableURLRequest *)request
{
    NSString *credString = [NSString stringWithFormat:@"%@:%@", [credential user], [credential password]];
    NSData *credStringAsData = [credString dataUsingEncoding:NSISOLatin1StringEncoding];
    NSData *credStringEncodedAsData = [credStringAsData encodeBase64WithLineLength:0 andNewlineAtEnd:NO];
    NSString *credStringEncoded = [NSString stringWithData:credStringEncodedAsData encoding:NSASCIIStringEncoding];
    NSString *authHeaderValue = [NSString stringWithFormat:@"Basic %@", credStringEncoded];
    [request setValue:authHeaderValue forHTTPHeaderField:@"Authorization"];
}

- (void)cancelRequest
{
	if(nsurlConnection == nil)
		return;
	[nsurlConnection cancel];
    [self cleanUpAfterRequest];
}


- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    NSString *method = [[challenge protectionSpace] authenticationMethod];
    if([method isEqualToString:NSURLAuthenticationMethodServerTrust])
    {
        const SecTrustRef serverTrust = [[challenge protectionSpace] serverTrust];
        if([self shouldContinueWithServerTrust:serverTrust])
        {
            NSURLCredential *serverTrustCredential = [NSURLCredential credentialForTrust:serverTrust];
            [[challenge sender] useCredential:serverTrustCredential forAuthenticationChallenge:challenge];
        }
        else
        {
            [[challenge sender] rejectProtectionSpaceAndContinueWithChallenge:challenge];
        }
    }
    else if([method isEqualToString:NSURLAuthenticationMethodHTTPBasic] || [method isEqualToString:NSURLAuthenticationMethodHTTPDigest])
    {
        if(([challenge previousFailureCount] == 0) && ((credential != nil) || [self setUpCredential]))
            [[challenge sender] useCredential:credential forAuthenticationChallenge:challenge];
        else
            [[challenge sender] cancelAuthenticationChallenge:challenge];
    }
    else
    {
        [[challenge sender] rejectProtectionSpaceAndContinueWithChallenge:challenge];
    }
}

- (BOOL)shouldContinueWithServerTrust:(SecTrustRef)secTrust
{
    SecTrustResultType result;
    SecTrustEvaluate(secTrust, &result);
    switch(result)
    {
        case kSecTrustResultUnspecified:
        case kSecTrustResultProceed:
            return YES;

        case kSecTrustResultRecoverableTrustFailure:
        {
            if([[NSUserDefaults standardUserDefaults] boolForKey:@"AskWhenCertIsUnverifiable"] == NO)
                return NO;
            
            SFCertificateTrustPanel *panel = [SFCertificateTrustPanel sharedCertificateTrustPanel];
            NSString *msg = [NSString stringWithFormat:@"CCMenu can't verify the identity of the server %@.", [feedURL host]];
            [panel setInformativeText:@"The certificate for this server is invalid. Do you want to continue anyway?"];
            [panel setAlternateButtonTitle:@"Cancel"];
            return ([panel runModalForTrust:secTrust message:msg] == NSOKButton);
        }

        default:
            return NO;
    }
}


- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    receivedResponse = (NSHTTPURLResponse *)[response retain];
    // doc says this could be called multiple times, so we reset data
    [receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [receivedData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    if([self responseIsHudsonJenkinsAuthRequest] && (useHudsonJenkinsAuthWorkaround == NO))
    {
        [self cleanUpAfterRequest];
        useHudsonJenkinsAuthWorkaround = YES;
        [self requestServerStatus];
        return;
    }
    if([receivedResponse statusCode] != 200)
    {
        [self cleanUpAfterRequest];
        [delegate connection:self hadTemporaryError:[self errorStringForResponse:receivedResponse]];
        return;
    }
    CCMXmlServerStatusReader *reader = [[[CCMXmlServerStatusReader alloc] initWithServerResponse:receivedData] autorelease];
    if (reader.isXml) {
        [self cleanUpAfterRequest];
        NSError *error = nil;
        NSArray *infos = [reader readProjectInfos:&error];
        if(infos != nil)
            [delegate connection:self didReceiveServerStatus:infos];
        else
            [delegate connection:self hadTemporaryError:[self errorStringForParseError:error]];
    }
    else {
    
        CCMBotsServerStatusReader* botsReader = [[[CCMBotsServerStatusReader alloc] initWithServerResponse:receivedData fromBaseURL:connection.currentRequest.URL.absoluteString] autorelease];
        
        [self cleanUpAfterRequest];
        NSError *error = nil;
        NSArray *infos = [botsReader readProjectInfos:&error];
        if(infos != nil)
            [delegate connection:self didReceiveServerStatus:infos];
        else
            [delegate connection:self hadTemporaryError:[self errorStringForParseError:error]];
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self cleanUpAfterRequest];
	[delegate connection:self hadTemporaryError:[self errorStringForError:error]];
}


- (BOOL)responseIsHudsonJenkinsAuthRequest
{
    NSDictionary *headerFields = [receivedResponse allHeaderFields];
    return (([receivedResponse statusCode] == 403) &&
            (([headerFields objectForKey:@"X-Hudson"] != nil) || ([headerFields objectForKey:@"X-Jenkins"] != nil)));
}


- (NSString *)errorStringForError:(NSError *)error
{
    NSString *description = [error localizedDescription];
    if([[error domain] isEqualToString:NSURLErrorDomain] && ([error code] == NSURLErrorUserCancelledAuthentication))
    {
        description = @"Server requires authentication and there is a problem with the credentials. Please verify the connection details for the project.";
    }
    return [NSString stringWithFormat:@"Failed to get status from %@: %@",
             [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey],
             description];
}

- (NSString *)errorStringForResponse:(NSHTTPURLResponse *)response
{
    return [NSString stringWithFormat:@"Failed to get status from %@: %@",
             [response URL],
             [NSHTTPURLResponse localizedStringForStatusCode:[response statusCode]]];
}

- (NSString *)errorStringForParseError:(NSError *)error
{
    return [NSString stringWithFormat:@"Failed to parse status from %@: %@ (Maybe the server is returning a temporary HTML error page instead of an XML document.)",
             [feedURL description],
             [[error localizedDescription] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
}

@end
