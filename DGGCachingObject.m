//*******************************************************************************

// Copyright (c) 2011 Danny Greg

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

// Created by Danny Greg on 20/12/2011

//*******************************************************************************

#import "DGGCachingObject.h"

#import "NSObject+DGGCaching.h"

#import <objc/runtime.h>

@implementation DGGCachingObject

+ (NSSet *)cachedKeys
{
    return [NSSet set];
}

+ (NSSet *)dgg_cachedKeys
{
    return [[self class] cachedKeys];
}

- (id)init
{	
	self = [super init];
	if (self == nil)
		return nil;
	
	[self dgg_initializeCaching];
    
    unsigned int propertyCount = 0;
    objc_property_t *propertyList = class_copyPropertyList([self class], &propertyCount);
    NSMutableDictionary *customGetters = [NSMutableDictionary dictionary];
    for (NSUInteger idx = 0; idx < propertyCount; idx ++) {
        NSString *propertyName = [NSString stringWithCString:property_getName(propertyList[idx]) encoding:NSUTF8StringEncoding];
        char *getterValue = property_copyAttributeValue(propertyList[idx], "G");
        if (getterValue != nil) {
            [customGetters setObject:[NSString stringWithCString:getterValue encoding:NSUTF8StringEncoding] forKey:propertyName];
        }
    }
    
    NSSet *cachedKeys = [[self class] cachedKeys];
    for (NSString *keyPath in cachedKeys) {
        NSString *selectorNameToSwizzle = [keyPath copy];
        if ([[customGetters allKeys] containsObject:keyPath]) {
            selectorNameToSwizzle = [customGetters objectForKey:keyPath];
        }
        
        class_getMethodImplementation([self class], NSSelectorFromString(selectorNameToSwizzle));
        //swizzle their getter implementation
        // Get the method for the selector
        // Set the method implementation 
        // Make sure we deal with returning the correct type using method_getReturnType
    }

	return self;
}

- (void)dealloc
{
	[self dgg_cachingTeardown];
    
#if !__has_feature(objc_arc)
	[super dealloc];
#endif
}

@end
