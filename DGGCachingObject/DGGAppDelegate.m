//
//  DGGAppDelegate.m
//  DGGCachingObject
//
//  Created by Danny Greg on 20/12/2011.
//  Copyright (c) 2011 No Thirst Software. All rights reserved.
//

#import "DGGAppDelegate.h"

@interface DGGAppDelegate ()

@property (nonatomic, copy) NSString *string;
@property (nonatomic, readonly) NSString *descriptionString;

@end

@implementation DGGAppDelegate

@synthesize window = _window;
@synthesize string = _string;

+ (NSSet *)keyPathsForValuesAffectingDescriptionString
{
    return [NSSet setWithObject:@"string"];
}

+ (NSSet *)cachedKeys
{
    return [NSSet setWithObject:@"descriptionString"];
}

- (IBAction)logDescriptionString:(id)sender
{
	NSLog(@"%@", self.descriptionString);
}

- (IBAction)changeString:(id)sender
{
	self.string = [[NSProcessInfo processInfo] globallyUniqueString];
    [self logDescriptionString:sender];
}


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    [self changeString:nil];
}

- (NSString *)descriptionString
{
    NSLog(@"%@", @"Generating value");
    return [NSString stringWithFormat:@"The new value of string is: %@", self.string];
}

@end
