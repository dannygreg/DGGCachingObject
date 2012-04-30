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

#import "NSObject+DGKVOBlocks.h"

#import <objc/runtime.h>
#import <objc/message.h>

//***************************************************************************

NSString *const DGGCachingObjectCachedObjectsAssociatedObjectKey = @"DGGCachingObjectCachedObjectsAssociatedObjectKey";
NSString *const DGGCachingObjectBlockObserversAssociatedObjectKey = @"DGGCachingObjectBlockObserversAssociatedObjectKey";
NSString *const DGGCachingObjectCacheRefreshFunctionsAssociatedObjectKey = @"DGGCachingObjectCacheRefreshFunctionsAssociatedObjectKey";

//***************************************************************************

@interface NSObject (DGGCaching_Private)

@property (nonatomic, copy) NSMutableDictionary *dgg_cachedObjects;
@property (nonatomic, copy) NSMutableArray *dgg_blockObservers;
@property (nonatomic, copy) NSMutableDictionary *dgg_cacheRefreshFunctions; //Mapped to their key

@end

//***************************************************************************

@implementation NSObject (DGGCaching_Private)

- (void)setDgg_cachedObjects:(NSMutableDictionary *)cachedObjects
{
    objc_setAssociatedObject(self, &DGGCachingObjectCachedObjectsAssociatedObjectKey, cachedObjects, OBJC_ASSOCIATION_COPY);
}

- (NSMutableDictionary *)dgg_cachedObjects
{
    return objc_getAssociatedObject(self, &DGGCachingObjectCachedObjectsAssociatedObjectKey);
}

- (void)setDgg_blockObservers:(NSMutableArray *)dgg_blockObservers
{
    objc_setAssociatedObject(self, &DGGCachingObjectBlockObserversAssociatedObjectKey, dgg_blockObservers, OBJC_ASSOCIATION_COPY);
}

- (NSMutableArray *)dgg_blockObservers
{
    return objc_getAssociatedObject(self, &DGGCachingObjectBlockObserversAssociatedObjectKey);
}

- (void)setDgg_cacheRefreshFunctions:(NSMutableDictionary *)dgg_cacheRefreshFunctions
{
	objc_setAssociatedObject(self, &DGGCachingObjectCacheRefreshFunctionsAssociatedObjectKey, dgg_cacheRefreshFunctions, OBJC_ASSOCIATION_COPY);
}

- (NSMutableDictionary *)dgg_cacheRefreshFunctions
{
	return objc_getAssociatedObject(self, &DGGCachingObjectCacheRefreshFunctionsAssociatedObjectKey);
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
    self.dgg_blockObservers = [NSMutableArray array];
    
    for (NSString *key in [[self class] dgg_cachedKeys]) {
        for (NSString *dependantKey in [[self class] keyPathsForValuesAffectingValueForKey:key]) {
            [self dgkvo_addObserverForKeyPath:dependantKey options:0 queue:nil usingBlock: ^ (NSDictionary *change) 
            {
                //if one of the dependencies reload the cache
                for (NSString *keyToBeCached in [[self class] dgg_cachedKeys]) {
                    if ([[[self class] keyPathsForValuesAffectingValueForKey:keyToBeCached] containsObject:dependantKey]) {
                        [self dgg_refreshCacheForKey:keyToBeCached queue:dispatch_get_current_queue()];
                        break; //Don't need to do it more than once, even if it is effected by multiple keys
                    }
                } 
            }];
        }
    }
	
	NSString *className = [NSString stringWithFormat:@"%@_DGGCaching", [self className]];
	Class dynamicSubclass = objc_allocateClassPair([self class], className.UTF8String, 0);
	objc_registerClassPair(dynamicSubclass);
	
	unsigned int propertyCount = 0;
    objc_property_t *propertyList = class_copyPropertyList(dynamicSubclass, &propertyCount);
    NSMutableDictionary *customGetters = [NSMutableDictionary dictionary];
    for (NSUInteger idx = 0; idx < propertyCount; idx ++) {
        NSString *propertyName = [NSString stringWithCString:property_getName(propertyList[idx]) encoding:NSUTF8StringEncoding];
        char *getterValue = property_copyAttributeValue(propertyList[idx], "G");
        if (getterValue != nil) {
            [customGetters setObject:[NSString stringWithCString:getterValue encoding:NSUTF8StringEncoding] forKey:propertyName];
        }
    }
        
    NSSet *cachedKeys = [dynamicSubclass dgg_cachedKeys];
    for (NSString *keyPath in cachedKeys) {
        NSString *selectorNameToSwizzle = [keyPath copy];
        if ([[customGetters allKeys] containsObject:keyPath]) {
            selectorNameToSwizzle = [customGetters objectForKey:keyPath];
        }
		
		Method targetMethod = class_getInstanceMethod(dynamicSubclass, NSSelectorFromString(selectorNameToSwizzle));
		IMP oldImplementation = method_getImplementation(targetMethod);
		
		
		char *methodReturnType = method_copyReturnType(targetMethod);
		IMP cacheReturningIMP = nil;
		switch (methodReturnType[0]) { //This is by far the worst thing about this… unfortunately I see no way around it… short of just not supporting primitive types
			case '@':
				cacheReturningIMP = imp_implementationWithBlock( ^ (id _s) {
					return [_s dgg_cachedValueForKey:keyPath];
				});
				break;
			case 'c':
				cacheReturningIMP = imp_implementationWithBlock( ^ (id _s) {
					NSNumber *returnedNumber = [_s dgg_cachedValueForKey:keyPath];
					return returnedNumber.charValue;
				});
				break;
				
			case 'i':
				cacheReturningIMP = imp_implementationWithBlock( ^ (id _s) {
					NSNumber *returnedNumber = [_s dgg_cachedValueForKey:keyPath];
					return returnedNumber.intValue;
				});
				break;
			case 's':
				cacheReturningIMP = imp_implementationWithBlock(^ (id _s) {
					NSNumber *returnedNumber = [_s dgg_cachedValueForKey:keyPath];
					return returnedNumber.shortValue;
				});
				break;
			case 'l':
				cacheReturningIMP = imp_implementationWithBlock(^ (id _s) {
					NSNumber *returnedNumber = [_s dgg_cachedValueForKey:keyPath];
					return returnedNumber.longValue;
				});
				break;
			case 'q':
				cacheReturningIMP = imp_implementationWithBlock(^ (id _s) {
					NSNumber *returnedNumber = [_s dgg_cachedValueForKey:keyPath];
					return returnedNumber.longLongValue;
				});
				break;
			case 'C':
				cacheReturningIMP = imp_implementationWithBlock(^ (id _s) {
					NSNumber *returnedNumber = [_s dgg_cachedValueForKey:keyPath];
					return returnedNumber.unsignedCharValue;
				});
				break;
			case 'I':
				cacheReturningIMP = imp_implementationWithBlock(^ (id _s) {
					NSNumber *returnedNumber = [_s dgg_cachedValueForKey:keyPath];
					return returnedNumber.unsignedIntValue;
				});
				break;
			case 'S':
				cacheReturningIMP = imp_implementationWithBlock(^ (id _s) {
					NSNumber *returnedNumber = [_s dgg_cachedValueForKey:keyPath];
					return returnedNumber.unsignedShortValue;
				});
				break;
			case 'L':
				cacheReturningIMP = imp_implementationWithBlock(^ (id _s) {
					NSNumber *returnedNumber = [_s dgg_cachedValueForKey:keyPath];
					return returnedNumber.unsignedLongValue;
				});
				break;
			case 'Q':
				cacheReturningIMP = imp_implementationWithBlock(^ (id _s) {
					NSNumber *returnedNumber = [_s dgg_cachedValueForKey:keyPath];
					return returnedNumber.unsignedLongLongValue;
				});
				break;
			case 'f':
				cacheReturningIMP = imp_implementationWithBlock(^ (id _s) {
					NSNumber *returnedNumber = [_s dgg_cachedValueForKey:keyPath];
					return returnedNumber.floatValue;
				});
				break;
			case 'd':
				cacheReturningIMP = imp_implementationWithBlock(^ (id _s) {
					NSNumber *returnedNumber = [_s dgg_cachedValueForKey:keyPath];
					return returnedNumber.doubleValue;
				});
				break;
				// This is somewhat of an incomplete list… we should cover structs etc. too
			default:
				break;
		}

        method_setImplementation(targetMethod, cacheReturningIMP);
    }

	object_setClass(self, dynamicSubclass);
//	struct objc_super superTarget = {self, class_getSuperclass(dynamicSubclass)};
//	Method classMethod = class_getInstanceMethod(dynamicSubclass, @selector(class));
//	method_setImplementation(classMethod, imp_implementationWithBlock( ^ (id _s) {
//		return objc_msgSendSuper((struct objc_super *)&superTarget, @selector(class));
//	}));
}

- (void)dgg_cachingTeardown
{
    for (id observer in self.dgg_blockObservers)
        [self dgkvo_removeObserverWithIdentifier:observer];
    
    self.dgg_cachedObjects = nil;
    self.dgg_blockObservers = nil;
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
//    if (queue == nil)
//        queue = dispatch_get_main_queue();
//    
//    dispatch_sync(queue, ^ {
        if (key == nil)
            return;
        
        id objectToCache = [self valueForKey:key];
        if (objectToCache == nil) {
            @synchronized (self.dgg_cachedObjects) {
                [self.dgg_cachedObjects removeObjectForKey:key];
            }
            return;
        }
        
        @synchronized (self.dgg_cachedObjects) {
            [self.dgg_cachedObjects setObject:objectToCache forKey:key];
        }
    //});
}

@end
