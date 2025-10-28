
//
//  OneKeepAlive.m
//  Única dylib para substituir ICEnabled + Notifications2
//
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#ifndef OKA_LOG
#define OKA_LOG 0
#endif
#define OKALog(fmt, ...) do { if (OKA_LOG) NSLog(@"[OneKeepAlive] " fmt, ##__VA_ARGS__); } while(0)

static BOOL oka_isRecording(void) {
    AVAudioSession *s = [AVAudioSession sharedInstance];
    if ([s.category isEqualToString:AVAudioSessionCategoryPlayAndRecord]) return YES;
    for (AVAudioSessionPortDescription *p in s.currentRoute.inputs) {
        if ([p.portType isEqualToString:AVAudioSessionPortBuiltInMic] ||
            [p.portType isEqualToString:AVAudioSessionPortHeadsetMic] ||
            [p.portType isEqualToString:AVAudioSessionPortBluetoothHFP]) return YES;
    }
    return NO;
}

static void oka_applyForeground(void) {
    AVAudioSession *s = [AVAudioSession sharedInstance];
    NSError *err = nil;
    if (oka_isRecording()) {
        [s setActive:NO error:&err];
        err = nil;
        [s setCategory:AVAudioSessionCategoryAmbient error:&err];
    } else {
        [s setCategory:AVAudioSessionCategoryAmbient
            withOptions:AVAudioSessionCategoryOptionMixWithOthers
                  error:&err];
        err = nil;
        [s setActive:YES error:&err];
    }
}

static void oka_applyBackground(void) {
    AVAudioSession *s = [AVAudioSession sharedInstance];
    NSError *err = nil;
    [s setCategory:AVAudioSessionCategoryPlayback
        withOptions:AVAudioSessionCategoryOptionMixWithOthers
              error:&err];
    err = nil;
    [s setActive:YES error:&err];
}

static void oka_reapply(void) {
    UIApplicationState st = UIApplication.sharedApplication.applicationState;
    if (st == UIApplicationStateBackground || st == UIApplicationStateInactive) oka_applyBackground();
    else oka_applyForeground();
}

static void oka_swizzle(Class c, SEL o, SEL r) {
    Method m1 = class_getInstanceMethod(c, o);
    Method m2 = class_getInstanceMethod(c, r);
    if (m1 && m2) method_exchangeImplementations(m1, m2);
}

@interface AVAudioSession (OKA)
- (BOOL)oka_setActive:(BOOL)active error:(NSError**)e;
- (BOOL)oka_setCategory:(NSString*)cat error:(NSError**)e;
- (BOOL)oka_setCategory:(NSString*)cat withOptions:(AVAudioSessionCategoryOptions)opt error:(NSError**)e;
@end

@implementation AVAudioSession (OKA)
- (BOOL)oka_setActive:(BOOL)active error:(NSError**)e {
    oka_reapply();
    return [self oka_setActive:active error:e];
}
- (BOOL)oka_setCategory:(NSString*)cat error:(NSError**)e {
    if ([cat isEqualToString:AVAudioSessionCategoryPlayback])
        return [self oka_setCategory:cat withOptions:AVAudioSessionCategoryOptionMixWithOthers error:e];
    return [self oka_setCategory:cat error:e];
}
- (BOOL)oka_setCategory:(NSString*)cat withOptions:(AVAudioSessionCategoryOptions)opt error:(NSError**)e {
    if ([cat isEqualToString:AVAudioSessionCategoryPlayback]) {
        opt |= AVAudioSessionCategoryOptionMixWithOthers;
        opt &= ~AVAudioSessionCategoryOptionDuckOthers;
    }
    return [self oka_setCategory:cat withOptions:opt error:e];
}
@end

__attribute__((constructor))
static void oka_init(void) {
    Class cls = [AVAudioSession class];
    oka_swizzle(cls, @selector(setActive:error:), @selector(oka_setActive:error:));
    oka_swizzle(cls, @selector(setCategory:error:), @selector(oka_setCategory:error:));
    oka_swizzle(cls, @selector(setCategory:withOptions:error:), @selector(oka_setCategory:withOptions:error:));

    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:nil usingBlock:^(__unused NSNotification *n){ oka_applyBackground(); }];
    [nc addObserverForName:UIApplicationWillEnterForegroundNotification object:nil queue:nil usingBlock:^(__unused NSNotification *n){ oka_applyForeground(); }];
    [nc addObserverForName:AVAudioSessionInterruptionNotification object:nil queue:nil usingBlock:^(__unused NSNotification *n){ oka_reapply(); }];
    [nc addObserverForName:AVAudioSessionRouteChangeNotification object:nil queue:nil usingBlock:^(__unused NSNotification *n){ oka_reapply(); }];
}
