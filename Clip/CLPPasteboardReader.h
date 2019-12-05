//
//  CLPPasteboardReader.h
//  Clip
//
//  Created by Riley Testut on 10/30/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CLPPasteboardReader : NSObject

+ (void)loadMe;
+ (void)checkPasteboard;

- (void)beginListeningToPasteboardChangeNotifications;

@end

NS_ASSUME_NONNULL_END
