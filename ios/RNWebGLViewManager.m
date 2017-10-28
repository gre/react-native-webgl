#import "RNWebGLViewManager.h"
#import "RNWebGLView.h"

#import <React/RCTUIManager.h>

@interface RNWebGLViewManager ()

@property (nonatomic, strong) NSMutableDictionary<NSNumber *, RNWebGLView *> *arSessions;
@property (nonatomic, assign) NSUInteger nextARSessionId;

@end

@implementation RNWebGLViewManager

RCT_EXPORT_MODULE(RNWebGLViewManager);

@synthesize bridge = _bridge;

- (instancetype)init
{
  if ((self = [super init])) {
    _arSessions = [NSMutableDictionary dictionary];
    _nextARSessionId = 0;
  }
  return self;
}

- (UIView *)view
{
  return [[RNWebGLView alloc] initWithManager:self];
}

RCT_EXPORT_VIEW_PROPERTY(onSurfaceCreate, RCTDirectEventBlock);
RCT_EXPORT_VIEW_PROPERTY(msaaSamples, NSNumber);

RCT_REMAP_METHOD(startARSessionAsync,
                 startARSessionAsyncWithReactTag:(nonnull NSNumber *)tag
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  NSUInteger sessionId = _nextARSessionId++;
  [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
    UIView *view = viewRegistry[tag];
    if (![view isKindOfClass:[RNWebGLView class]]) {
      reject(@"E_GLVIEW_MANAGER_BAD_VIEW_TAG", nil, RCTErrorWithMessage(@"RNWebGLViewManager.startARSessionAsync: Expected an RNWebGLView"));
      return;
    }
    RNWebGLView *rnwebglView = (RNWebGLView *)view;
    _arSessions[@(sessionId)] = rnwebglView;

    NSMutableDictionary *response = [[rnwebglView maybeStartARSession] mutableCopy];
    if (response[@"error"]) {
      reject(@"ERR_ARKIT_FAILED_TO_INIT", response[@"error"], RCTErrorWithMessage(response[@"error"]));
    } else {
      response[@"sessionId"] = @(sessionId);
      resolve(response);
    }
  }];
}

RCT_REMAP_METHOD(stopARSessionAsync,
                 stopARSessionAsyncWithId:(nonnull NSNumber *)sessionId
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
  [self.bridge.uiManager addUIBlock:^(__unused RCTUIManager *uiManager, NSDictionary<NSNumber *, UIView *> *viewRegistry) {
    RNWebGLView *rnwebglView = _arSessions[sessionId];
    if (rnwebglView) {
      [rnwebglView maybeStopARSession];
      [_arSessions removeObjectForKey:sessionId];
    }
    resolve(nil);
  }];
}

RCT_REMAP_BLOCKING_SYNCHRONOUS_METHOD(getARMatrices,
                                      getARMatricesWithSessionId:(nonnull NSNumber *)sessionId
                                      viewportWidth:(nonnull NSNumber *)vpWidth
                                      viewportHeight:(nonnull NSNumber *)vpHeight
                                      zNear:(nonnull NSNumber *)zNear
                                      zFar:(nonnull NSNumber *)zFar)
{
  RNWebGLView *rnwebglView = _arSessions[sessionId];
  if (!rnwebglView) {
    return nil;
  }
  return [rnwebglView arMatricesForViewportSize:CGSizeMake([vpWidth floatValue], [vpHeight floatValue])
                                       zNear:[zNear floatValue]
                                        zFar:[zFar floatValue]];
}

@end
