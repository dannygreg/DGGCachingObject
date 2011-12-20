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

#import "NSObject+DGGCaching.h"

#import <objc/runtime.h>

//***************************************************************************

NSString *const DGGCachingObjectCachedObjectsAssociatedObjectKey = @"DGGCachingObjectCachedObjectsAssociatedObjectKey";
NSString *DGGCachingObjectKeyChangeObservationContext = @"DGGCachingObjectKeyChangeObservationContext";

//***************************************************************************

@interface NSObject (DGGCaching_Private)

@property (nonatomic, copy) NSMutableDictionary *dgg_cachedObjects;

@end

//***************************************************************************

@implementation NSObject (DGGCaching_Private)

- (void)setDgg_cachedObjects:(NSMutableDictionary *)cachedObjects
{
    objc_setAssociatedObject(self, &DGGCachingObjectKeyChangeObservationContext, cachedObjects, OBJC_ASSOCIATION_COPY);
}

- (NSMutableDictionary *)dgg_cachedObjects
{
    return objc_getAssociatedObject(self, &DGGCachingObjectKeyChangeObservationContext);
}

@end

//***************************************************************************

@implementation NSObject (DGGCaching)

+ (NSSet *)dgg_cachedKeys
{
    return [NSSet set];
}

- (void)dgg_initializeCaching
{
    self.dgg_cachedObjects = [NSMutableDictionary dictionary];
    for (NSString *key in [[self class] dgg_cachedKeys]) {
        for (NSString *dependantKey in [[self class] keyPathsForValuesAffectingValueForKey:key]) {
            [self addObserver:self forKeyPath:dependantKey options:0 context:&DGGCachingObjectKeyChangeObservationContext];
        }
    }
}

- (void)dgg_cachingTeardown
{
    self.dgg_cachedObjects = nil;
    for (NSString *key in [[self class] dgg_cachedKeys]) {
        for (NSString *dependantKey in [[self class] keyPathsForValuesAffectingValueForKey:key]) {
            [self removeObserver:self forKeyPath:dependantKey context:&DGGCachingObjectKeyChangeObservationContext];
        }
    }
}

- (id)dgg_cachedValueForKey:(NSString *)key
{
    id storedObject = [self.dgg_cachedObjects objectForKey:key];
    if (storedObject == nil && [[[self class] dgg_cachedKeys] containsObject:key]) {
        [self dgg_refreshCacheForKey:key queue:nil];
        storedObject = [self.dgg_cachedObjects objectForKey:key];
    }
    
    return (storedObject ?: [self valueForKey:key]);
}

- (void)dgg_refreshCacheForKey:(NSString *)key queue:(dispatch_queue_t)queue
{
    
}

@end
