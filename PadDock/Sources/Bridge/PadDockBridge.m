#import "PadDockBridge.h"
#import "DisplaySafety.h"
#import <CoreGraphics/CoreGraphics.h>
#import <IOKit/IOKitLib.h>
#import <dlfcn.h>

// These are runtime-resolved system interfaces, deliberately isolated here.
@interface NSObject (PDSystemInterfaces)
+ (id)sharedManager;
- (NSArray *)devices;
- (NSArray *)connectedDevices;
- (id)identifier;
- (NSString *)name;
- (id)model;
- (id)configForDevice:(id)device;
- (void)setTransport:(NSInteger)transport;
- (void)connectToDevice:(id)device withConfig:(id)config completion:(void (^)(NSError *))completion;
- (void)disconnectFromDevice:(id)device completion:(void (^)(NSError *))completion;
- (id)initWithDescriptor:(id)descriptor;
- (BOOL)applySettings:(id)settings;
- (id)initWithWidth:(unsigned int)width height:(unsigned int)height refreshRate:(double)refresh;
- (void)setSizeInMillimeters:(CGSize)size;
@end

@interface PDNative () {
    id _manager;
    id _anchor;
    IONotificationPortRef _usbPort;
    io_iterator_t _added;
    io_iterator_t _removed;
}
@end

static NSArray *USBDevices(void) {
    io_iterator_t iterator=0;
    NSMutableArray *result=[NSMutableArray array];
    if(IOServiceGetMatchingServices(kIOMainPortDefault,IOServiceMatching("IOUSBHostDevice"),&iterator)!=KERN_SUCCESS) return result;
    io_service_t device;
    while((device=IOIteratorNext(iterator))) {
        NSString *name=CFBridgingRelease(IORegistryEntryCreateCFProperty(device,CFSTR("USB Product Name"),kCFAllocatorDefault,0));
        NSString *serial=CFBridgingRelease(IORegistryEntryCreateCFProperty(device,CFSTR("USB Serial Number"),kCFAllocatorDefault,0));
        if([name isKindOfClass:NSString.class] && [name localizedCaseInsensitiveContainsString:@"iPad"] && [serial isKindOfClass:NSString.class] && serial.length) {
            [result addObject:@{@"name":name,@"serial":serial}];
        }
        IOObjectRelease(device);
    }
    IOObjectRelease(iterator);
    return result;
}
static void USBNotify(void *context,io_iterator_t iterator) {
    io_service_t device;
    while((device=IOIteratorNext(iterator))) IOObjectRelease(device);
    PDNative *native=(__bridge PDNative *)context;
    dispatch_async(dispatch_get_main_queue(),^{ if(native.usbChanged) native.usbChanged(); });
}

@implementation PDNative
- (instancetype)init {
    if((self=[super init])) {
        if(dlopen("/System/Library/PrivateFrameworks/SidecarCore.framework/SidecarCore",RTLD_NOW)) {
            Class cls=NSClassFromString(@"SidecarDisplayManager");
            if([cls respondsToSelector:@selector(sharedManager)]) _manager=[cls sharedManager];
        }
    }
    return self;
}
- (BOOL)available {
    for(NSString *selector in @[@"devices",@"connectedDevices",@"configForDevice:",@"connectToDevice:withConfig:completion:",@"disconnectFromDevice:completion:"]) {
        if(![_manager respondsToSelector:NSSelectorFromString(selector)]) return NO;
    }
    return YES;
}
- (uint32_t)anchorID { return _anchor ? [[_anchor valueForKey:@"displayID"] unsignedIntValue] : 0; }
- (id)findDevice:(NSString *)identifier {
    if(!self.available) return nil;
    for(id d in [_manager devices]) if([d respondsToSelector:@selector(identifier)] && [[[d identifier] description] isEqualToString:identifier]) return d;
    return nil;
}
- (uint32_t)displayForDevice:(id)device {
    id config=[_manager configForDevice:device];
    if(![config respondsToSelector:NSSelectorFromString(@"displayID")]) return 0;
    id value=[config valueForKey:@"displayID"];
    return [value respondsToSelector:@selector(unsignedIntValue)] ? [value unsignedIntValue] : 0;
}
- (NSDictionary *)snapshot {
    @try {
        NSMutableArray *devices=[NSMutableArray array];
        if(self.available) for(id d in [_manager devices]) {
            if(![d respondsToSelector:@selector(identifier)] || ![d respondsToSelector:@selector(name)]) continue;
            BOOL connected=[[_manager connectedDevices] containsObject:d];
            uint32_t display=connected ? [self displayForDevice:d] : 0;
            id config=connected ? [_manager configForDevice:d] : nil;
            NSNumber *transport=[config respondsToSelector:NSSelectorFromString(@"transport")] ? [config valueForKey:@"transport"] : @0;
            NSString *model=[d respondsToSelector:@selector(model)] ? [[d model] description] : @"";
            // Only expose iPads, not other possible SidecarCore device families.
            if(![model hasPrefix:@"iPad"]) continue;
            [devices addObject:@{@"id":[[d identifier] description],@"name":[d name] ?: @"iPad",@"model":model,
                @"connected":@(connected),@"displayID":@(display),@"displayOnline":@(display && CGDisplayIsOnline(display)),@"transport":transport ?: @0}];
        }
        NSDictionary *session=CFBridgingRelease(CGSessionCopyCurrentDictionary());
        BOOL locked=!session || [session[@"CGSSessionScreenIsLocked"] boolValue] || ![session[(__bridge NSString *)kCGSessionOnConsoleKey] boolValue];
        CGDirectDisplayID ids[32]; uint32_t count=0;
        NSMutableArray *displays=[NSMutableArray array];
        if(CGGetOnlineDisplayList(32,ids,&count)==kCGErrorSuccess) for(uint32_t i=0;i<count;i++) {
            [displays addObject:@{@"id":@(ids[i]),@"main":@(CGDisplayIsMain(ids[i])),@"builtIn":@(CGDisplayIsBuiltin(ids[i])),@"mirrorOf":@(CGDisplayMirrorsDisplay(ids[i])),@"anchor":@(ids[i]==self.anchorID)}];
        }
        return @{@"usb":USBDevices(),@"devices":devices,@"locked":@(locked),@"available":@(self.available),@"anchorID":@(self.anchorID),@"displays":displays};
    } @catch(NSException *error) {
        (void)error;
        return @{@"usb":USBDevices(),@"devices":@[],@"locked":@YES,@"available":@NO,@"anchorID":@(self.anchorID),@"displays":@[]};
    }
}
- (void)connectDevice:(NSString *)identifier completion:(void (^)(NSString *))completion {
    @try {
        id d=[self findDevice:identifier];
        if(!d) { completion(@"未发现所选 iPad。请解锁设备并确认随航可用。"); return; }
        id config=[[NSClassFromString(@"SidecarDisplayConfig") alloc] init];
        if(![config respondsToSelector:@selector(setTransport:)]) { completion(@"当前系统暂时无法使用随航。"); return; }
        [config setTransport:2];
        [_manager connectToDevice:d withConfig:config completion:^(NSError *error) {
            NSString *message=error ? @"连接失败，请解锁 iPad 并检查 Apple 账户。" : nil;
            dispatch_async(dispatch_get_main_queue(),^{ completion(message); });
        }];
    } @catch(NSException *error) { (void)error; completion(@"暂时无法连接，请稍后重试。"); }
}
- (void)disconnectDevice:(NSString *)identifier completion:(void (^)(NSString *))completion {
    @try {
        id d=[self findDevice:identifier];
        if(!d) { completion(nil); return; }
        [_manager disconnectFromDevice:d completion:^(NSError *error) {
            NSString *message=error ? @"未能断开随航，请在系统显示器设置中检查。" : nil;
            dispatch_async(dispatch_get_main_queue(),^{ completion(message); });
        }];
    } @catch(NSException *error) { (void)error; completion(@"系统未能完成断开请求。"); }
}
- (NSString *)createAnchor {
    if(_anchor) return nil;
    @try {
        Class dc=NSClassFromString(@"CGVirtualDisplayDescriptor"), vc=NSClassFromString(@"CGVirtualDisplay"), mc=NSClassFromString(@"CGVirtualDisplayMode"), sc=NSClassFromString(@"CGVirtualDisplaySettings");
        if(!dc || !vc || !mc || !sc) return @"当前系统暂不支持仅用 iPad 显示。";
        id descriptor=[[dc alloc] init];
        [descriptor setValuesForKeysWithDictionary:@{@"name":@"PadDock Display",@"maxPixelsWide":@5120,@"maxPixelsHigh":@3200,@"vendorID":@0xF0B1,@"productID":@0xA016,@"serialNum":@0x5044001}];
        if([descriptor respondsToSelector:NSSelectorFromString(@"setSerialNumber:")]) [descriptor setValue:@0x5044001 forKey:@"serialNumber"];
        [descriptor setValue:dispatch_get_main_queue() forKey:@"queue"];
        [descriptor setSizeInMillimeters:CGSizeMake(250,174)];
        id display=[[vc alloc] initWithDescriptor:descriptor];
        if(!display) return @"未能开启，请保留其他显示器后重试。";
        NSMutableArray *modes=[NSMutableArray array];
        for(NSArray *size in @[@[@1180,@820],@[@1116,@820],@[@1366,@1024],@[@1920,@1080],@[@2560,@1440],@[@2560,@1600]]) {
            id mode=[[mc alloc] initWithWidth:[size[0] unsignedIntValue] height:[size[1] unsignedIntValue] refreshRate:60];
            if(mode) [modes addObject:mode];
        }
        id settings=[[sc alloc] init]; [settings setValue:modes forKey:@"modes"]; [settings setValue:@1 forKey:@"hiDPI"];
        if(![display applySettings:settings]) return @"未能开启，请稍后重试。";
        _anchor=display;
        return nil;
    } @catch(NSException *error) { (void)error; return @"当前系统暂不支持仅用 iPad 显示。"; }
}
- (NSString *)mirrorAnchorToDevice:(NSString *)identifier {
    if(!_anchor) return nil;
    @try {
        uint32_t anchor=self.anchorID;
        if(!CGDisplayIsOnline(anchor)) return @"正在准备画面，请稍候。";
        id device=[self findDevice:identifier];
        uint32_t source=device ? [self displayForDevice:device] : 0;
        if(!source || !CGDisplayIsOnline(source)) source=CGMainDisplayID();
        if(!source || source==anchor || !CGDisplayIsOnline(source)) return nil;
        if(CGDisplayMirrorsDisplay(anchor)==source || CGDisplayMirrorsDisplay(source)==anchor) return nil;
        CGDisplayConfigRef config=NULL; CGError e=CGBeginDisplayConfiguration(&config);
        if(e==kCGErrorSuccess) {
            e=CGConfigureDisplayMirrorOfDisplay(config,anchor,source);
            if(e==kCGErrorSuccess) e=CGCompleteDisplayConfiguration(config,kCGConfigureForSession);
            else CGCancelDisplayConfiguration(config);
        }
        return e==kCGErrorSuccess ? nil : @"画面设置失败，请稍后重试。";
    } @catch(NSException *error) { (void)error; return @"未能更新画面，请稍后重试。"; }
}
- (BOOL)canReleaseAnchor {
    if(!_anchor) return YES;
    @try {
        if(!self.available) return NO;
        uint32_t sidecar[32]; size_t sidecarCount=0;
        for(id d in [_manager connectedDevices]) {
            CGDirectDisplayID display=[self displayForDevice:d];
            if(!display || sidecarCount>=32) return NO;
            sidecar[sidecarCount++]=display;
        }
        CGDirectDisplayID ids[32]; uint32_t count=0;
        if(CGGetOnlineDisplayList(32,ids,&count)!=kCGErrorSuccess) return NO;
        return PDCanReleaseSupport(true, true, true, self.anchorID, ids, count, sidecar, sidecarCount);
    } @catch(NSException *error) { (void)error; return NO; }
}
- (void)releaseAnchor { _anchor=nil; }
- (void)startUSBMonitoring {
    if(_usbPort) return;
    _usbPort=IONotificationPortCreate(kIOMainPortDefault);
    if(!_usbPort) return;
    CFRunLoopSourceRef source=IONotificationPortGetRunLoopSource(_usbPort);
    if(source) CFRunLoopAddSource(CFRunLoopGetMain(),source,kCFRunLoopCommonModes);
    if(IOServiceAddMatchingNotification(_usbPort,kIOFirstMatchNotification,IOServiceMatching("IOUSBHostDevice"),USBNotify,(__bridge void *)self,&_added)==KERN_SUCCESS) USBNotify((__bridge void *)self,_added);
    if(IOServiceAddMatchingNotification(_usbPort,kIOTerminatedNotification,IOServiceMatching("IOUSBHostDevice"),USBNotify,(__bridge void *)self,&_removed)==KERN_SUCCESS) USBNotify((__bridge void *)self,_removed);
}
- (void)dealloc {
    if(_added) IOObjectRelease(_added);
    if(_removed) IOObjectRelease(_removed);
    if(_usbPort) IONotificationPortDestroy(_usbPort);
}
@end
