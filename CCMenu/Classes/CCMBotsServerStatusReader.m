//
//  CCMJsonServerStatusReader.m
//  CCMenu
//
//  Created by Travis Bader on 7/6/16.
//  Copyright © 2016 ThoughtWorks. All rights reserved.
//

#import "CCMBotsServerStatusReader.h"

@implementation CCMBotsServerStatusReader {
    NSData* _responseData;
    NSString* _baseURL;
}

-(id)initWithServerResponse:(NSData*)data fromBaseURL:(NSString*)url {
    self = [super init];
    if (self) {
        _responseData = [data copy];
        _baseURL = [url copy];
    }
    return self;
}

-(void)dealloc {
    [_responseData release];
    [_baseURL release];
    [super dealloc];
}

-(NSArray*)readProjectInfos:(NSError**)errorPtr {
    if (_responseData == nil)
        return @[];
    
    NSMutableArray* integrations = [NSMutableArray new];
    NSDictionary* parsedJson = [NSJSONSerialization JSONObjectWithData:_responseData options:0 error:errorPtr];

    for (NSDictionary* result in parsedJson[@"results"]) {
        NSMutableDictionary* integration = [[NSMutableDictionary new] retain];
        
        integration[@"name"] = result[@"name"];
        integration[@"lastBuildLabel"] = ((NSNumber*)result[@"integration_counter"]).stringValue;
        
        NSString* integrationURL = [NSString stringWithFormat:@"%@/%@/integrations?last=1", _baseURL, result[@"_id"]];
        NSError* error = nil;
        NSData* integrationData = [NSData dataWithContentsOfURL:[NSURL URLWithString:integrationURL]];
        if (integrationData == nil)
            continue;
        
        NSDictionary* integrationJSON = [NSJSONSerialization JSONObjectWithData:integrationData options:0 error:&error];
        NSDictionary* integrationResult = ((NSArray*)integrationJSON[@"results"]).firstObject;
        integration[@"webUrl"] = [NSString stringWithFormat:@"xcbot://%@/botID/%@/integrationID/%@/", [NSURL URLWithString:_baseURL].host, result[@"_id"], integrationResult[@"_id"]];
        
        if (!error) {
            integration[@"lastBuildTime"] = integrationResult[@"endedTime"];
            
            NSString* activity = [self activityFromJson:integrationResult];
            integration[@"activity"] = activity;
            integration[@"lastBuildStatus"] = activity;
            if ([activity isEqualToString:@"Building"]) {
                integration[@"lastBuildStatus"] = nil;//@"Success";
            }
        }
        
        [integrations addObject:integration];
    }
    return integrations;
}

-(NSString*)xcodeUrlFromBaseXcodeURL:(NSString*)baseURL {
    NSURL* oldURL = [NSURL URLWithString:baseURL];
    NSString* host = oldURL.host;
    return [NSString stringWithFormat:@"xcbot://%@/", host];
}

-(NSString*)activityFromJson:(NSDictionary*)dictionary {
    NSString* activity = dictionary[@"currentStep"];
    NSString* resultString = dictionary[@"result"];
    NSLog(@"activity %@, result %@", activity, resultString);
    if ([activity isEqualToString:@"completed"]) {
        if (resultString == nil || [resultString isEqualToString:@"trigger-error"] || [resultString isEqualToString:@"canceled"] || [resultString isEqualToString:@"build-errors"] || [resultString isEqualToString:@"internal-build-error"] || [resultString isEqualToString:@"test-failures"]) {
            return @"Failure";
        }
        else {
            return  @"Success";
        }
    }
    return @"Building";
}

@end
