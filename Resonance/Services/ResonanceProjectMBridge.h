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

#ifdef __cplusplus
extern "C" {
#endif

typedef struct ResonanceNativeProjectM ResonanceNativeProjectM;
typedef struct ResonancePreparedLyric ResonancePreparedLyric;

ResonanceNativeProjectM * _Nullable resonance_native_projectm_create(void);
void resonance_native_projectm_destroy(ResonanceNativeProjectM * _Nonnull renderer);
bool resonance_native_projectm_is_ready(const ResonanceNativeProjectM * _Nullable renderer);
void resonance_native_projectm_set_window_size(ResonanceNativeProjectM * _Nonnull renderer, size_t width, size_t height);
void resonance_native_projectm_set_texture_paths(ResonanceNativeProjectM * _Nonnull renderer, const char * _Nonnull primaryPath, const char * _Nullable secondaryPath);
bool resonance_native_projectm_load_preset_file(ResonanceNativeProjectM * _Nonnull renderer, const char * _Nonnull path, bool smoothTransition);
void resonance_native_projectm_add_stereo_pcm(ResonanceNativeProjectM * _Nonnull renderer, const float * _Nullable samples, size_t frameCount);
void resonance_native_projectm_render(ResonanceNativeProjectM * _Nonnull renderer);
void resonance_native_projectm_set_target_framebuffer(ResonanceNativeProjectM * _Nonnull renderer, unsigned int framebuffer);
bool resonance_native_projectm_set_lyric_text(ResonanceNativeProjectM * _Nonnull renderer, const char * _Nonnull utf8Text);
ResonancePreparedLyric * _Nullable resonance_projectm_prepare_lyric(const char * _Nonnull utf8Text);
bool resonance_native_projectm_apply_prepared_lyric(ResonanceNativeProjectM * _Nonnull renderer, const ResonancePreparedLyric * _Nonnull prepared);
void resonance_projectm_destroy_prepared_lyric(ResonancePreparedLyric * _Nonnull prepared);
void resonance_native_projectm_set_lyric_progress(ResonanceNativeProjectM * _Nonnull renderer, float progress);
void resonance_native_projectm_clear_lyric(ResonanceNativeProjectM * _Nonnull renderer);

#ifdef __cplusplus
}
#endif
