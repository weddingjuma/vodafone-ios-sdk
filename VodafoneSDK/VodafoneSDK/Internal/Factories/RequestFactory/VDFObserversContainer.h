//
//  VDFObserversContainer.h
//  VodafoneSDK
//
//  Created by Michał Szymańczyk on 04/08/14.
//  Copyright (c) 2014 VOD. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 *  Container of observers
 */
@protocol VDFObserversContainer <NSObject>

/**
 *  List of all registered Observers
 *
 *  @return List of observers.
 */
- (NSArray*)registeredObservers;

/**
 *  Sets selector which need to be called on each observer.
 *  If specified observer do not contains specified method it won't be called on this observer.
 *
 *  @param selector Selector to the observer method.
 */
- (void)setObserversNotifySelector:(SEL)selector;

/**
 *  Register observer object in container with call priority set to 0.
 *  If observer already is registered in container nothing happends.
 *
 *  @param observer Observer object which will be registered.
 */
- (void)registerObserver:(id)observer;

/**
 *  Register observer object in container with specified priority to call.
 *  If observer already is registered in container nothing happends.
 *
 *  @param observer        Observer object which will be registered.
 *  @param priority Priority to call, highier priority means that observer will be called as first. Lower priority is called later.
 */
- (void)registerObserver:(id)observer withPriority:(NSInteger)priority;

/**
 *  Remove observer from container.
 *  If observer is not registered in container there nothing happends.
 *
 *  @param observer Oberver object which will be removed.
 */
- (void)unregisterObserver:(id)observer;

/**
 *  Notifies all registered observers with specified response and error objects.
 *
 *  @param object Object which need to be passed to each observer.
 *  @param error  Error object to pass to the observer.
 */
- (void)notifyAllObserversWith:(id)object error:(NSError*)error;

/**
 *  Number of registered observers.
 *
 *  @return Number of observers.
 */
- (NSUInteger)count;

@end
