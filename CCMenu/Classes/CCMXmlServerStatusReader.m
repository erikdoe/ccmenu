
#import "CCMXmlServerStatusReader.h"


@implementation CCMXmlServerStatusReader

- (id)initWithServerResponse:(NSData *)data
{
	self = [super init];
	responseData = [data copy];
	return self;
}

- (void)dealloc
{
	[responseData release];
	[super dealloc];
}

- (NSDate *)convertDateString:(NSString *)dateString
{
    // see http://stackoverflow.com/questions/2201216/is-there-a-simple-way-of-converting-an-iso8601-timestamp-to-a-formatted-nsdate
    NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
    if([dateString length] <= 19)
    {
        // assume old-style CruiseControl timestamp without timezone, assume local time
        [formatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss"];
        [formatter setTimeZone:[NSTimeZone localTimeZone]];
    }
    else if([[dateString substringFromIndex:[dateString length] - 1] isEqualToString:@"Z"])
    {
        // ISO8601 with Zulu/GMT time marker, used by Jenkins for example
        [formatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"];
        [formatter setTimeZone:[NSTimeZone timeZoneWithName:@"UTC"]];
    }
    else
    {
        // anything else, if there's a numerical timzone we try to help the formatter by inserting a blank and "GMT"
        [formatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss ZZZZ"];
        NSCharacterSet *tzIndicator = [NSCharacterSet characterSetWithCharactersInString:@"+-"];
        NSRange r = [dateString rangeOfCharacterFromSet:tzIndicator options:NSBackwardsSearch];
        if(r.location == [dateString length] - 5 || r.location == [dateString length] - 6)
        {
            NSRange rr = NSMakeRange(19, r.location - 19);
            dateString = [dateString stringByReplacingCharactersInRange:rr withString:@" "];
        }
    }
    return [formatter dateFromString:dateString];
}

- (NSString *)fixUrlStringIfNecessary:(NSString *)urlString
{
	// The following is a workaround for a CruiseControl.rb bug
	NSRange ppRange = [urlString rangeOfString:@"projectsprojects"];
	if(ppRange.length > 0)
	{
		NSMutableString *copy = [NSMutableString stringWithString:urlString];
		[copy replaceCharactersInRange:ppRange withString:@"projects"];
		urlString = copy;
	}
	return urlString;
}

-(BOOL)isXml {
    return [[[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding] hasPrefix:@"<"];
}

- (NSArray *)readProjectInfos:(NSError **)errorPtr
{
    NSXMLDocument *doc = [[[NSXMLDocument alloc] initWithData:responseData options:NSXMLNodeOptionsNone error:errorPtr] autorelease];
    if(doc == nil)
        return nil;
    
    NSMutableArray *projectInfos = [NSMutableArray array];
    for(NSXMLElement *element in [doc nodesForXPath:@"//Project" error:nil])
	{
		NSDictionary *info = [NSMutableDictionary dictionary];
        for(NSXMLNode *attribute in [element attributes])
		{
			id value = [attribute stringValue];
			if([[attribute name] isEqualToString:@"lastBuildTime"])
				value = [self convertDateString:value];
			if([[attribute name] isEqualToString:@"webUrl"])
				value = [self fixUrlStringIfNecessary:value];
			[info setValue:value forKey:[attribute name]];
		}
		[projectInfos addObject:info];
	}
    return projectInfos;        
}

@end
