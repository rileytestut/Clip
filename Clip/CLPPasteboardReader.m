//
//  CLPPasteboardReader.m
//  Clip
//
//  Created by Riley Testut on 10/30/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

#import "CLPPasteboardReader.h"
#import <dlfcn.h>
#import <notify.h>

@protocol PBClientToServerProtocol <NSObject>
- (void)getAllPasteboardsCompletionBlock:(void (^)(NSArray *, NSError *))arg1;
- (void)performJanitorialTasksCompletionBlock:(void (^)(void))arg1;
- (void)didPasteContentsFromPasteboardWithName:(NSString *)arg1 UUID:(NSUUID *)arg2 completionBlock:(void (^)(void))arg3;
- (void)requestItemFromPasteboardWithName:(NSString *)arg1 UUID:(NSUUID *)arg2 itemIndex:(unsigned long long)arg3 typeIdentifier:(NSString *)arg4 completionBlock:(void (^)(NSData *, id, NSError *))arg5;
- (void)deletePersistentPasteboardWithName:(NSString *)arg1 completionBlock:(void (^)(unsigned long long, NSError *))arg2;
- (void)savePasteboard:(id)arg1 dataProviderEndpoint:(NSXPCListenerEndpoint *)arg2 completionBlock:(void (^)(unsigned long long, long long, NSError *))arg3;
- (void)localGeneralPasteboardCompletionBlock:(void (^)(id, NSError *))arg1;
- (void)pasteboardWithName:(NSString *)arg1 createIfNeeded:(_Bool)arg2 completionBlock:(void (^)(id, NSError *))arg3;
- (void)helloCompletionBlock:(void (^)(void))arg1;

@end

@interface RSTDummy : NSObject
{
}

- (long long)changeCount; // @synthesize changeCount=_changeCount;
- (id)pasteboardTypes; // @synthesize numberOfItems=_numberOfItems;

+ (id)sharedManager;
- (id)typeAliases;

+ (id)defaultConnection;

+ (id)sharedInstance;
+ (id)delegate;
+ (id)identifier;
- (id)fetchedPasteboardItem;
- (NSString *)text;

+ (unsigned long long)beginListeningToPasteboardChangeNotifications;

@property(readonly, nonatomic) NSXPCConnection *serverConnection;


+ (struct __CFArray *)copyAllPasteboards;


- (void)requestItemFromPasteboardWithName:(NSString *)arg1 UUID:(NSUUID *)arg2 itemIndex:(unsigned long long)arg3 typeIdentifier:(NSString *)arg4 completionBlock:(void (^)(NSData *, id, NSError *))arg5;

@end

@implementation CLPPasteboardReader

int notifyToken;

+ (void)loadMe
{
    NSBundle *bundle = [NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/Pasteboard.framework"];
    [bundle load];
    
    //    void *handle = dlopen("/System/Library/PrivateFrameworks/PersonalizationPortraitInternals.framework/PersonalizationPortraitInternals", RTLD_NOW);
    NSLog(@"Handle: %@", bundle.principalClass);
}

+ (void)checkPasteboard
{
    int status = notify_register_dispatch("PBPasteboardChangedNotifyNotification",
                                          &notifyToken,
                                          dispatch_get_main_queue(), ^(int t) {
                                              uint64_t state;
                                              int result = notify_get_state(notifyToken, &state);
                                              NSLog(@"lock state change = %llu", state);
                                              if (result != NOTIFY_STATUS_OK) {
                                                  NSLog(@"notify_get_state() not returning NOTIFY_STATUS_OK");
                                              }
                                          });
    if (status != NOTIFY_STATUS_OK) {
        NSLog(@"notify_register_dispatch() not returning NOTIFY_STATUS_OK");
    }
}

BOOL didStart = NO;

+ (void)checkPasteboard2
{
    Class klass = NSClassFromString(@"PBServerConnection");
//    id identifier = [klass identifier];
    RSTDummy *instance = [klass defaultConnection];
    
    if (!didStart)
    {
        [klass beginListeningToPasteboardChangeNotifications];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pasteboardChanged:) name:@"com.apple.pasteboard.changed" object:nil];
        
        didStart = YES;
    }
    

    NSXPCConnection *connection = instance.serverConnection;


    id<PBClientToServerProtocol> proxy = connection.remoteObjectProxy;
    
    [proxy localGeneralPasteboardCompletionBlock:^(id itemCollection, NSError *error) {
        NSLog(@"Item: %@", itemCollection);
    }];

//    NSLog(@"KLASS: %@ %@ %@ %@", klass, instance, connection, proxy);
}

+ (void)pasteboardChanged:(NSNotification *)notification
{
    NSLog(@"Pasteboard changed: %@", notification);
}

@end
