#import "ResonanceProjectMBridge.h"

#include <algorithm>
#include <cmath>
#include <dlfcn.h>
#include <mutex>
#include <string>
#include <vector>

#include <OpenGLES/ES3/gl.h>

#include "projectM-4/audio.h"
#include "projectM-4/callbacks.h"
#include "projectM-4/core.h"
#include "projectM-4/parameters.h"
#include "projectM-4/render_opengl.h"

@interface ResonanceProjectMBridge () {
    projectm_handle _instance;
    EAGLContext *_context;
}
@end

namespace {
std::mutex gAudioMutex;
std::vector<float> gPendingPCM;
NSUInteger gPendingChannels = 2;
constexpr size_t kProjectMMeshWidth = 24;
constexpr size_t kProjectMMeshHeight = 24;
constexpr size_t kProjectMMaximumTextureDimension = 1024;

// projectM's default resolver targets desktop GL loader libraries. iOS keeps
// the OpenGL ES entry points in the OpenGLES framework, so resolve them from
// the already-loaded process instead.
void *iosOpenGLESLoadProc(const char *name, void *) {
    return dlsym(RTLD_DEFAULT, name);
}

void projectMPresetFailed(const char *filename, const char *message, void *) {
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
        _context = view.context;
        [EAGLContext setCurrentContext:view.context];
        const GLubyte *version = glGetString(GL_VERSION);
        const GLubyte *shadingLanguage = glGetString(GL_SHADING_LANGUAGE_VERSION);
        NSLog(@"[projectM] iOS GL context: version=%s glsl=%s",
              version != nullptr ? (const char *)version : "<none>",
              shadingLanguage != nullptr ? (const char *)shadingLanguage : "<none>");
        _instance = projectm_create_with_opengl_load_proc(iosOpenGLESLoadProc, nullptr);
        NSLog(@"[projectM] create result: %s", _instance != nullptr ? "ready" : "failed");
        if (_instance != nullptr) {
            projectm_set_preset_switch_failed_event_callback(_instance, projectMPresetFailed, nullptr);
            projectm_set_fps(_instance, 60);
            projectm_set_preset_duration(_instance, 15.0);
            projectm_set_soft_cut_duration(_instance, 1.0);
            projectm_set_mesh_size(_instance, kProjectMMeshWidth, kProjectMMeshHeight);
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
    if (samples == nullptr || count == 0) {
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
    GLint framebuffer = 0;
    glGetIntegerv(GL_FRAMEBUFFER_BINDING, &framebuffer);
    projectm_opengl_render_frame_fbo(_instance, static_cast<uint32_t>(std::max(framebuffer, 0)));
    GLenum error = glGetError();
    if (error != GL_NO_ERROR) {
        NSLog(@"[projectM] GL error after frame: 0x%04x", error);
    }
}

- (void)resizeToWidth:(NSUInteger)width height:(NSUInteger)height {
    if (_instance != nullptr && width > 0 && height > 0) {
        const double scale = std::min(
            1.0,
            static_cast<double>(kProjectMMaximumTextureDimension) /
                static_cast<double>(std::max(width, height))
        );
        const size_t renderWidth = std::max<size_t>(
            1,
            static_cast<size_t>(std::lround(static_cast<double>(width) * scale))
        );
        const size_t renderHeight = std::max<size_t>(
            1,
            static_cast<size_t>(std::lround(static_cast<double>(height) * scale))
        );
        projectm_set_window_size(_instance, renderWidth, renderHeight);
    }
}

- (void)loadPresetAtPath:(NSString *)path smooth:(BOOL)smooth {
    if (_instance == nullptr || path.length == 0) {
        return;
    }
    projectm_load_preset_file(_instance, path.fileSystemRepresentation, smooth);
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
