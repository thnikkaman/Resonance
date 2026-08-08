#import "ResonanceProjectMBridge.h"
#import <UIKit/UIKit.h>

#include <algorithm>
#include <atomic>
#include <cstdio>
#include <cstring>
#include <mutex>
#include <string>
#include <vector>

#include <OpenGLES/ES3/gl.h>

#include "projectM-4/audio.h"
#include "projectM-4/callbacks.h"
#include "projectM-4/core.h"
#include "projectM-4/parameters.h"
#include "projectM-4/render_opengl.h"

extern "C" void resonance_diagnostics_record(const char *event,
                                               const char *key,
                                               const char *value);

@interface ResonanceProjectMBridge () {
    projectm_handle _instance;
    EAGLContext *_context;
}
@property(nonatomic, weak) GLKView *view;
@end

struct ResonanceNativeProjectM {
    projectm_handle handle = nullptr;
    unsigned int targetFramebuffer = 0;
    std::string primaryTexturePath;
    std::string secondaryTexturePath;
    std::string lastError;
    bool presetLoadFailed = false;
};

struct ResonancePreparedLyric {
    std::vector<unsigned char> pixels;
    int width = 0;
    int height = 0;
    size_t characterCount = 0;
    double preparationMilliseconds = 0;
};

namespace {
std::atomic<bool> gNativeVisualizerAudioEnabled{false};
std::mutex gAudioMutex;
std::vector<float> gPendingPCM;
NSUInteger gPendingChannels = 2;
}

static void ResonanceNativePresetFailed(const char *filename, const char *message, void *userData) {
    auto *renderer = static_cast<ResonanceNativeProjectM *>(userData);
    if (renderer == nullptr) {
        return;
    }
    renderer->presetLoadFailed = true;
    renderer->lastError = std::string(filename == nullptr ? "" : filename) + ": " +
        (message == nullptr ? "unknown projectM preset error" : message);
}

extern "C" ResonanceNativeProjectM *resonance_native_projectm_create(void) {
    auto *renderer = new ResonanceNativeProjectM();
    renderer->handle = projectm_create();
    if (renderer->handle != nullptr) {
        gNativeVisualizerAudioEnabled.store(true, std::memory_order_release);
        projectm_set_preset_switch_failed_event_callback(renderer->handle, ResonanceNativePresetFailed, renderer);
        projectm_set_fps(renderer->handle, 60);
        projectm_set_aspect_correction(renderer->handle, true);
        projectm_set_soft_cut_duration(renderer->handle, 1.0);
    }
    resonance_diagnostics_record("projectm.native.create", "ready",
                                 renderer->handle != nullptr ? "true" : "false");
    return renderer;
}

extern "C" void resonance_native_projectm_destroy(ResonanceNativeProjectM *renderer) {
    if (renderer == nullptr) return;
    gNativeVisualizerAudioEnabled.store(false, std::memory_order_release);
    {
        std::lock_guard<std::mutex> lock(gAudioMutex);
        gPendingPCM.clear();
    }
    if (renderer->handle != nullptr) projectm_destroy(renderer->handle);
    resonance_diagnostics_record("projectm.native.destroy", "reason", "renderer_inactive");
    delete renderer;
}

extern "C" bool resonance_native_projectm_is_ready(const ResonanceNativeProjectM *renderer) {
    return renderer != nullptr && renderer->handle != nullptr;
}

extern "C" void resonance_native_projectm_set_window_size(ResonanceNativeProjectM *renderer, size_t width, size_t height) {
    if (resonance_native_projectm_is_ready(renderer)) {
        projectm_set_window_size(renderer->handle, width, height);
        char value[64];
        snprintf(value, sizeof(value), "%zux%zu", width, height);
        resonance_diagnostics_record("projectm.native.window_size", "size", value);
    }
}

extern "C" void resonance_native_projectm_set_texture_paths(ResonanceNativeProjectM *renderer, const char *primaryPath, const char *secondaryPath) {
    if (!resonance_native_projectm_is_ready(renderer)) return;
    const std::string nextPrimary = primaryPath == nullptr ? "" : primaryPath;
    const std::string nextSecondary = secondaryPath == nullptr ? "" : secondaryPath;
    if (renderer->primaryTexturePath == nextPrimary &&
        renderer->secondaryTexturePath == nextSecondary) {
        return;
    }
    renderer->primaryTexturePath = nextPrimary;
    renderer->secondaryTexturePath = nextSecondary;
    const char *paths[2] = { renderer->primaryTexturePath.c_str(), renderer->secondaryTexturePath.c_str() };
    const unsigned int count = renderer->secondaryTexturePath.empty() ? 1U : 2U;
    projectm_set_texture_search_paths(renderer->handle, paths, count);
}

extern "C" bool resonance_native_projectm_load_preset_file(ResonanceNativeProjectM *renderer, const char *path, bool smoothTransition) {
    if (!resonance_native_projectm_is_ready(renderer) || path == nullptr) return false;
    renderer->lastError.clear();
    renderer->presetLoadFailed = false;
    const CFTimeInterval started = CACurrentMediaTime();
    projectm_load_preset_file(renderer->handle, path, smoothTransition);
    const bool loaded = !renderer->presetLoadFailed && renderer->lastError.empty();
    char result[128];
    snprintf(result, sizeof(result), "result=%s smooth=%s duration_ms=%.1f",
             loaded ? "success" : "failed", smoothTransition ? "true" : "false",
             (CACurrentMediaTime() - started) * 1000.0);
    resonance_diagnostics_record("projectm.native.preset_load", "result", result);
    return loaded;
}

extern "C" void resonance_native_projectm_add_stereo_pcm(ResonanceNativeProjectM *renderer, const float *samples, size_t frameCount) {
    if (resonance_native_projectm_is_ready(renderer) && samples != nullptr && frameCount > 0) {
        projectm_pcm_add_float(renderer->handle, samples, static_cast<unsigned int>(frameCount), PROJECTM_STEREO);
    }
}

extern "C" void resonance_native_projectm_render(ResonanceNativeProjectM *renderer) {
    if (!resonance_native_projectm_is_ready(renderer)) return;
    std::vector<float> pcm;
    NSUInteger channels = 2;
    {
        std::lock_guard<std::mutex> lock(gAudioMutex);
        pcm.swap(gPendingPCM);
        channels = gPendingChannels;
    }
    if (!pcm.empty()) {
        projectm_pcm_add_float(renderer->handle,
                               pcm.data(),
                               static_cast<unsigned int>(pcm.size() / channels),
                               channels == 1 ? PROJECTM_MONO : PROJECTM_STEREO);
    }
    // The black-screen probe used synchronous GL state queries and 49 pixel
    // readbacks. That investigation is complete; the production render path
    // must not force GPU/CPU synchronization.
    projectm_opengl_render_frame(renderer->handle);
}

namespace {
std::vector<unsigned char> RasterizeLyricText(const char *utf8Text, int& width, int& height) {
    width = 1024;
    height = 256;
    NSString *text = utf8Text == nullptr ? @"" : [NSString stringWithUTF8String:utf8Text];
    if (text.length == 0) return {};

    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.opaque = YES;
    format.scale = 1.0;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc]
        initWithSize:CGSizeMake(width, height) format:format];
    UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [[UIColor blackColor] setFill];
        UIRectFill(CGRectMake(0, 0, width, height));

        NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
        paragraph.alignment = NSTextAlignmentCenter;
        paragraph.lineBreakMode = NSLineBreakByWordWrapping;
        const CGSize limit = CGSizeMake(width - 80, height - 36);
        CGFloat low = 24.0;
        CGFloat high = 92.0;
        UIFont *font = [UIFont boldSystemFontOfSize:low];
        NSDictionary *attributes = nil;
        for (int iteration = 0; iteration < 8; ++iteration) {
            const CGFloat candidateSize = (low + high) * 0.5;
            UIFontDescriptor *descriptor = [[UIFont boldSystemFontOfSize:candidateSize].fontDescriptor
                fontDescriptorWithDesign:UIFontDescriptorSystemDesignSerif];
            UIFont *candidate = [UIFont fontWithDescriptor:descriptor size:candidateSize];
            NSDictionary *candidateAttributes = @{
                NSFontAttributeName: candidate,
                NSForegroundColorAttributeName: UIColor.whiteColor,
                NSParagraphStyleAttributeName: paragraph
            };
            CGRect bounds = [text boundingRectWithSize:limit
                                               options:NSStringDrawingUsesLineFragmentOrigin |
                                                       NSStringDrawingUsesFontLeading
                                            attributes:candidateAttributes
                                               context:nil];
            if (bounds.size.width <= limit.width && bounds.size.height <= limit.height) {
                low = candidateSize;
                font = candidate;
                attributes = candidateAttributes;
            } else {
                high = candidateSize;
            }
        }
        if (attributes == nil) {
            attributes = @{
                NSFontAttributeName: font,
                NSForegroundColorAttributeName: UIColor.whiteColor,
                NSParagraphStyleAttributeName: paragraph
            };
        }
        CGRect bounds = [text boundingRectWithSize:limit
                                           options:NSStringDrawingUsesLineFragmentOrigin |
                                                   NSStringDrawingUsesFontLeading
                                        attributes:attributes
                                           context:nil];
        CGRect drawRect = CGRectMake(40, (height - ceil(bounds.size.height)) * 0.5,
                                     width - 80, ceil(bounds.size.height));
        [text drawWithRect:drawRect
                   options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                attributes:attributes
                   context:nil];
    }];

    std::vector<unsigned char> pixels(static_cast<size_t>(width * height * 4), 0);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef bitmap = CGBitmapContextCreate(pixels.data(), width, height, 8, width * 4,
                                                colorSpace,
                                                kCGBitmapByteOrder32Big |
                                                kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(colorSpace);
    if (bitmap == nullptr || image.CGImage == nullptr) {
        if (bitmap != nullptr) CGContextRelease(bitmap);
        return {};
    }
    CGContextTranslateCTM(bitmap, 0, height);
    CGContextScaleCTM(bitmap, 1, -1);
    CGContextDrawImage(bitmap, CGRectMake(0, 0, width, height), image.CGImage);
    CGContextRelease(bitmap);
    return pixels;
}
}

extern "C" bool resonance_native_projectm_set_lyric_text(ResonanceNativeProjectM *renderer,
                                                           const char *utf8Text) {
    auto *prepared = resonance_projectm_prepare_lyric(utf8Text);
    if (prepared == nullptr) return false;
    const bool applied = resonance_native_projectm_apply_prepared_lyric(renderer, prepared);
    resonance_projectm_destroy_prepared_lyric(prepared);
    return applied;
}

extern "C" ResonancePreparedLyric *resonance_projectm_prepare_lyric(const char *utf8Text) {
    if (utf8Text == nullptr) return nullptr;
    const CFTimeInterval started = CACurrentMediaTime();
    auto *prepared = new ResonancePreparedLyric();
    prepared->pixels = RasterizeLyricText(utf8Text, prepared->width, prepared->height);
    if (prepared->pixels.empty()) {
        delete prepared;
        return nullptr;
    }
    prepared->characterCount = strlen(utf8Text);
    prepared->preparationMilliseconds = (CACurrentMediaTime() - started) * 1000.0;
    return prepared;
}

extern "C" bool resonance_native_projectm_apply_prepared_lyric(
    ResonanceNativeProjectM *renderer,
    const ResonancePreparedLyric *prepared) {
    if (!resonance_native_projectm_is_ready(renderer) || prepared == nullptr ||
        prepared->pixels.empty()) return false;
    const CFTimeInterval started = CACurrentMediaTime();
    projectm_opengl_set_lyric_texture(renderer->handle, prepared->pixels.data(),
                                      prepared->width, prepared->height);
    char value[128];
    snprintf(value, sizeof(value),
             "characters=%zu texture=%dx%d prepare_ms=%.1f upload_ms=%.1f",
             prepared->characterCount, prepared->width, prepared->height,
             prepared->preparationMilliseconds,
             (CACurrentMediaTime() - started) * 1000.0);
    resonance_diagnostics_record("projectm.lyrics.native_upload", "result", value);
    return true;
}

extern "C" void resonance_projectm_destroy_prepared_lyric(ResonancePreparedLyric *prepared) {
    delete prepared;
}

extern "C" void resonance_native_projectm_set_lyric_progress(ResonanceNativeProjectM *renderer,
                                                               float progress) {
    if (resonance_native_projectm_is_ready(renderer)) {
        projectm_opengl_set_lyric_progress(renderer->handle, progress);
    }
}

extern "C" void resonance_native_projectm_clear_lyric(ResonanceNativeProjectM *renderer) {
    if (resonance_native_projectm_is_ready(renderer)) {
        projectm_opengl_clear_lyric_texture(renderer->handle);
    }
}

extern "C" void resonance_native_projectm_set_target_framebuffer(ResonanceNativeProjectM *renderer, unsigned int framebuffer) {
    if (resonance_native_projectm_is_ready(renderer)) {
        renderer->targetFramebuffer = framebuffer;
        projectm_opengl_set_target_framebuffer(renderer->handle, framebuffer);
    }
}

namespace {
// Temporary host-layer probe. When enabled, the GLKView drawable is cleared
// and presented without entering ProjectM, proving whether Resonance can show
// any OpenGL ES pixels before renderer-specific diagnosis continues.
constexpr bool kHostPresentationProbe = false;

void projectMPresetFailed(const char *filename, const char *message, void *) {
    resonance_diagnostics_record("projectm.preset.failed", "message",
                                 message != nullptr ? message : "unknown");
    NSLog(@"[projectM] preset failed: file=%s message=%s",
          filename != nullptr ? filename : "<none>",
          message != nullptr ? message : "<none>");
}
}

@implementation ResonanceProjectMBridge

- (instancetype)initWithView:(GLKView *)view {
    self = [super init];
    if (self) {
        NSAssert(view.context != nil, @"projectM requires a current OpenGL ES context");
        self.view = view;
    _context = view.context;
        resonance_diagnostics_record("projectm.bridge.create.begin", nullptr, nullptr);
        [EAGLContext setCurrentContext:view.context];
        const GLubyte *version = glGetString(GL_VERSION);
        const GLubyte *shadingLanguage = glGetString(GL_SHADING_LANGUAGE_VERSION);
        NSLog(@"[projectM] iOS GL context: version=%s glsl=%s",
              version != nullptr ? (const char *)version : "<none>",
              shadingLanguage != nullptr ? (const char *)shadingLanguage : "<none>");
        _instance = projectm_create();
        resonance_diagnostics_record("projectm.bridge.create.end", "ready",
                                     _instance != nullptr ? "true" : "false");
        NSLog(@"[projectM] create result: %s", _instance != nullptr ? "ready" : "failed");
        if (_instance != nullptr) {
            projectm_set_preset_switch_failed_event_callback(_instance, projectMPresetFailed, nullptr);
            projectm_set_fps(_instance, 60);
            projectm_set_aspect_correction(_instance, true);
            projectm_set_preset_duration(_instance, 15.0);
            projectm_set_soft_cut_duration(_instance, 1.0);
            [self resizeToWidth:view.drawableWidth height:view.drawableHeight];
        }
    }
    return self;
}

- (void)dealloc {
    if (_instance != nullptr) {
        projectm_destroy(_instance);
        _instance = nullptr;
    }
}

- (BOOL)isReady {
    return _instance != nullptr;
}

+ (void)submitPCM:(const float *)samples count:(NSUInteger)count channels:(NSUInteger)channels {
    if (!gNativeVisualizerAudioEnabled.load(std::memory_order_acquire)
        || samples == nullptr || count == 0) {
        return;
    }

    const NSUInteger safeChannels = channels == 0 ? 1 : std::min(channels, (NSUInteger)2);
    const NSUInteger scalarCount = count * safeChannels;
    std::lock_guard<std::mutex> lock(gAudioMutex);

    // Keep the callback-side copy bounded. projectM consumes the newest audio
    // window on the render thread, so stale samples are less useful than safety.
    constexpr NSUInteger maxScalars = 32768;
    if (gPendingPCM.size() + scalarCount > maxScalars) {
        const NSUInteger excess = gPendingPCM.size() + scalarCount - maxScalars;
        if (excess >= gPendingPCM.size()) {
            gPendingPCM.clear();
        } else {
            gPendingPCM.erase(gPendingPCM.begin(), gPendingPCM.begin() + excess);
        }
    }
    gPendingPCM.insert(gPendingPCM.end(), samples, samples + scalarCount);
    gPendingChannels = safeChannels;
}

- (void)drawFrame {
    if (_context != nil) {
        [EAGLContext setCurrentContext:_context];
    }
    if (_instance == nullptr) {
        resonance_diagnostics_record("projectm.frame.skipped", "reason", "instance_missing");
        return;
    }

    // Capture and retain GLKView's presentation framebuffer before calling any
    // ProjectM resize code. ProjectM's resize path updates its own offscreen
    // attachments and may change the currently bound framebuffer; the target
    // must be restored immediately before the final composite.
    GLint targetFramebuffer = 0;
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &targetFramebuffer);
    // GLKView does not allocate its drawable until it is first presented. The
    // initial size in initWithView: can therefore be zero. projectM skips a
    // frame when its native window size is zero, so refresh the size at the
    // same point ProjectMD does: inside the draw callback, after GLKView has
    // made the drawable current.
    static NSUInteger drawableMissingLogCount = 0;
    if (self.view.drawableWidth > 0 && self.view.drawableHeight > 0) {
        projectm_set_window_size(_instance,
                                 self.view.drawableWidth,
                                 self.view.drawableHeight);
        static NSUInteger sizeLogCount = 0;
        if (sizeLogCount < 3) {
            char size[64];
            snprintf(size, sizeof(size), "%zux%zu", self.view.drawableWidth, self.view.drawableHeight);
            resonance_diagnostics_record("projectm.drawable.ready", "size", size);
            sizeLogCount += 1;
        }
    } else if (drawableMissingLogCount < 3) {
        resonance_diagnostics_record("projectm.drawable.missing", "size", "0x0");
        drawableMissingLogCount += 1;
    }

    if (kHostPresentationProbe) {
        glViewport(0, 0, self.view.drawableWidth, self.view.drawableHeight);
        glClearColor(0.85f, 0.05f, 0.55f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        resonance_diagnostics_record("projectm.host_probe.presented", "color", "magenta");
        return;
    }

    size_t windowWidth = 0;
    size_t windowHeight = 0;
    projectm_get_window_size(_instance, &windowWidth, &windowHeight);
    GLint viewport[4] = {0, 0, 0, 0};
    glGetIntegerv(GL_VIEWPORT, viewport);
    static size_t lastWidth = 0;
    static size_t lastHeight = 0;
    if (windowWidth != lastWidth || windowHeight != lastHeight) {
        char windowSize[64];
        snprintf(windowSize, sizeof(windowSize), "%zux%zu", windowWidth, windowHeight);
        resonance_diagnostics_record("projectm.window.size", "size", windowSize);
        NSLog(@"[projectM] drawable=%zux%zu viewport=%d,%d %dx%d",
              windowWidth, windowHeight, viewport[0], viewport[1], viewport[2], viewport[3]);
        lastWidth = windowWidth;
        lastHeight = windowHeight;
    }

    std::vector<float> pcm;
    NSUInteger channels = 2;
    {
        std::lock_guard<std::mutex> lock(gAudioMutex);
        pcm.swap(gPendingPCM);
        channels = gPendingChannels;
    }
    if (!pcm.empty()) {
        projectm_pcm_add_float(_instance, pcm.data(), (unsigned int)(pcm.size() / channels),
                               channels == 1 ? PROJECTM_MONO : PROJECTM_STEREO);
    }
    // Match ProjectMD's working lifecycle: GLKView has already made the
    // drawable current, so retain its framebuffer as ProjectM's target without
    // rebinding it between resize/audio setup and the native render call.
    projectm_opengl_set_target_framebuffer(
        _instance,
        static_cast<uint32_t>(std::max(targetFramebuffer, 0)));
    GLint framebuffer = 0;
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &framebuffer);
    GLenum preexistingError = GL_NO_ERROR;
    while (true) {
        const GLenum error = glGetError();
        if (error == GL_NO_ERROR) {
            break;
        }
        preexistingError = error;
    }
    if (preexistingError != GL_NO_ERROR) {
        char errorValue[32];
        snprintf(errorValue, sizeof(errorValue), "0x%04x", preexistingError);
        resonance_diagnostics_record("projectm.frame.preexisting_gl_error", "error", errorValue);
    }
    const GLenum framebufferStatus = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (framebufferStatus != GL_FRAMEBUFFER_COMPLETE) {
        char statusValue[32];
        snprintf(statusValue, sizeof(statusValue), "0x%04x", framebufferStatus);
        resonance_diagnostics_record("projectm.frame.incomplete_target", "status", statusValue);
    }
    static NSUInteger frameLogCount = 0;
    if (frameLogCount < 3) {
        char framebufferValue[32];
        snprintf(framebufferValue, sizeof(framebufferValue), "%d", framebuffer);
        resonance_diagnostics_record("projectm.frame.begin", "framebuffer", framebufferValue);
        frameLogCount += 1;
    }
    projectm_opengl_render_frame(_instance);
    GLenum error = glGetError();
    if (error != GL_NO_ERROR) {
        char errorValue[32];
        snprintf(errorValue, sizeof(errorValue), "0x%04x", error);
        resonance_diagnostics_record("projectm.frame.gl_error", "error", errorValue);
        NSLog(@"[projectM] GL error after frame: 0x%04x", error);
    }
}

- (void)resizeToWidth:(NSUInteger)width height:(NSUInteger)height {
    if (_instance != nullptr && width > 0 && height > 0) {
        projectm_set_window_size(_instance, width, height);
    }
}

- (void)loadPresetAtPath:(NSString *)path smooth:(BOOL)smooth {
    if (_instance == nullptr || path.length == 0) {
        resonance_diagnostics_record("projectm.preset.skipped", "reason", "invalid_instance_or_path");
        return;
    }
    // Preset loading is initiated by SwiftUI rather than GLKView's draw
    // callback. projectM's load path performs DrawInitialImage and therefore
    // creates/binds OpenGL ES framebuffers. Make the bridge's context current
    // before entering that path; otherwise the first preset load can leave an
    // invalid framebuffer operation pending and every subsequent frame is
    // black.
    [EAGLContext setCurrentContext:_context];
    resonance_diagnostics_record("projectm.preset.load.begin", "smooth", smooth ? "true" : "false");
    projectm_load_preset_file(_instance, path.fileSystemRepresentation, smooth);
    resonance_diagnostics_record("projectm.preset.load.end", "exists",
                                 [[NSFileManager defaultManager] fileExistsAtPath:path] ? "true" : "false");
}

- (void)setTextureSearchPaths:(NSArray<NSString *> *)paths {
    if (_instance == nullptr || paths.count == 0) {
        return;
    }
    std::vector<const char *> cPaths;
    cPaths.reserve(std::min(paths.count, (NSUInteger)8));
    for (NSString *path in paths) {
        if (path.length > 0) {
            cPaths.push_back(path.fileSystemRepresentation);
        }
        if (cPaths.size() == 8) {
            break;
        }
    }
    if (!cPaths.empty()) {
        projectm_set_texture_search_paths(_instance, cPaths.data(), cPaths.size());
    }
}

@end
