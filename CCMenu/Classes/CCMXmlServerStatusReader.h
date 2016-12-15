
#import <Cocoa/Cocoa.h>


@interface CCMXmlServerStatusReader : NSObject 
{
	NSData *responseData;
}

- (id)initWithServerResponse:(NSData *)data;

- (NSArray *)readProjectInfos:(NSError **)errorPtr;

-(BOOL)isXml;

@end
