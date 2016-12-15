//
//  CCMJsonServerStatusReader.h
//  CCMenu
//
//  Created by Travis Bader on 7/6/16.
//  Copyright © 2016 ThoughtWorks. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CCMBotsServerStatusReader : NSObject

-(id)initWithServerResponse:(NSData*)data fromBaseURL:(NSString*)url;

-(NSArray*)readProjectInfos:(NSError**)errorPtr;

@end
