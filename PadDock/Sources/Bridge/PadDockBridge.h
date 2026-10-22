#import "../KeychainSupport/include/PadDockKeychainSupport.h"
#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface PDNative : NSObject
@property(nonatomic, copy, nullable) void (^usbChanged)(void);
@property(nonatomic, readonly) BOOL available;
@property(nonatomic, readonly) uint32_t anchorID;
- (NSDictionary<NSString *, id> *)snapshot;
- (void)connectDevice:(NSString *)identifier completion:(void (^)(NSString * _Nullable error))completion;
- (void)disconnectDevice:(NSString *)identifier completion:(void (^)(NSString * _Nullable error))completion;
- (nullable NSString *)createAnchor;
- (nullable NSString *)mirrorAnchorToDevice:(NSString *)identifier;
- (BOOL)canReleaseAnchor;
- (void)releaseAnchor;
- (void)startUSBMonitoring;
@end
NS_ASSUME_NONNULL_END
