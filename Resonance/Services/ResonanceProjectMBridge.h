#define GLES_SILENCE_DEPRECATION 1
#import <Foundation/Foundation.h>
#import <GLKit/GLKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Small Objective-C++ boundary around libprojectM. Rendering stays on the GLKView
/// draw thread; PCM submission only copies into a bounded staging buffer.
@interface ResonanceProjectMBridge : NSObject

- (instancetype)initWithView:(GLKView *)view;
+ (void)submitPCM:(const float *)samples count:(NSUInteger)count channels:(NSUInteger)channels;
- (void)drawFrame;
- (void)resizeToWidth:(NSUInteger)width height:(NSUInteger)height;
- (void)loadPresetAtPath:(NSString *)path smooth:(BOOL)smooth;
- (void)setTextureSearchPaths:(NSArray<NSString *> *)paths;

@property(nonatomic, readonly, getter=isReady) BOOL ready;

@end

NS_ASSUME_NONNULL_END
