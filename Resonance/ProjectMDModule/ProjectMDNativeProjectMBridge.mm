#include "ProjectMDNativeProjectMBridge.h"

#include <projectM-4/projectM.h>

#include <OpenGLES/ES3/gl.h>

#include <string>

namespace {
constexpr double kProjectMTransitionDurationSeconds = 1.0;
}

struct ProjectMDNativeProjectM {
    projectm_handle handle = nullptr;
    std::string primaryTexturePath;
    std::string secondaryTexturePath;
    std::string lastError;
    bool presetLoadFailed = false;
};

static void ProjectMNativePresetFailed(const char *presetFilename, const char *message, void *userData) {
    auto *renderer = static_cast<ProjectMDNativeProjectM *>(userData);
    if (renderer == nullptr) {
        return;
    }
    renderer->presetLoadFailed = true;
    renderer->lastError = std::string(presetFilename == nullptr ? "" : presetFilename) + ": " +
        (message == nullptr ? "unknown projectM preset error" : message);
}

ProjectMDNativeProjectM *projectmd_native_projectm_create(void) {
    auto *renderer = new ProjectMDNativeProjectM();
    renderer->handle = projectm_create();
    if (renderer->handle != nullptr) {
        projectm_set_preset_switch_failed_event_callback(renderer->handle, ProjectMNativePresetFailed, renderer);
        projectm_set_fps(renderer->handle, 60);
        projectm_set_aspect_correction(renderer->handle, true);
        projectm_set_soft_cut_duration(renderer->handle, kProjectMTransitionDurationSeconds);
    }
    return renderer;
}

void projectmd_native_projectm_destroy(ProjectMDNativeProjectM *renderer) {
    if (renderer == nullptr) {
        return;
    }
    if (renderer->handle != nullptr) {
        projectm_destroy(renderer->handle);
    }
    delete renderer;
}

bool projectmd_native_projectm_is_ready(const ProjectMDNativeProjectM *renderer) {
    return renderer != nullptr && renderer->handle != nullptr;
}

const char *projectmd_native_projectm_last_error(const ProjectMDNativeProjectM *renderer) {
    return renderer == nullptr ? nullptr : renderer->lastError.c_str();
}

void projectmd_native_projectm_set_window_size(ProjectMDNativeProjectM *renderer, size_t width, size_t height) {
    if (projectmd_native_projectm_is_ready(renderer)) {
        projectm_set_window_size(renderer->handle, width, height);
    }
}

void projectmd_native_projectm_set_texture_path(ProjectMDNativeProjectM *renderer, const char *path) {
    if (!projectmd_native_projectm_is_ready(renderer) || path == nullptr || path[0] == '\0') {
        return;
    }
    renderer->primaryTexturePath = path;
    const char *paths[] = { renderer->primaryTexturePath.c_str() };
    projectm_set_texture_search_paths(renderer->handle, paths, 1);
}

void projectmd_native_projectm_set_texture_paths(ProjectMDNativeProjectM *renderer, const char *primaryPath, const char *secondaryPath) {
    if (!projectmd_native_projectm_is_ready(renderer)) {
        return;
    }
    renderer->primaryTexturePath = primaryPath == nullptr ? "" : primaryPath;
    renderer->secondaryTexturePath = secondaryPath == nullptr ? "" : secondaryPath;
    const char *paths[2] = { renderer->primaryTexturePath.c_str(), renderer->secondaryTexturePath.c_str() };
    const unsigned int count = renderer->secondaryTexturePath.empty() ? 1U : 2U;
    projectm_set_texture_search_paths(renderer->handle, paths, count);
}

bool projectmd_native_projectm_load_preset_file(ProjectMDNativeProjectM *renderer, const char *path, bool smooth_transition) {
    if (projectmd_native_projectm_is_ready(renderer) && path != nullptr) {
        renderer->lastError.clear();
        renderer->presetLoadFailed = false;
        projectm_load_preset_file(renderer->handle, path, smooth_transition);
        return !renderer->presetLoadFailed && renderer->lastError.empty();
    }
    return false;
}

bool projectmd_native_projectm_load_preset_data(ProjectMDNativeProjectM *renderer, const char *data, bool smooth_transition) {
    if (projectmd_native_projectm_is_ready(renderer) && data != nullptr) {
        renderer->lastError.clear();
        renderer->presetLoadFailed = false;
        projectm_load_preset_data(renderer->handle, data, smooth_transition);
        return !renderer->presetLoadFailed && renderer->lastError.empty();
    }
    return false;
}

void projectmd_native_projectm_add_stereo_pcm(ProjectMDNativeProjectM *renderer, const float *samples, size_t frame_count) {
    if (projectmd_native_projectm_is_ready(renderer) && samples != nullptr && frame_count > 0) {
        projectm_pcm_add_float(renderer->handle, samples, static_cast<unsigned int>(frame_count), PROJECTM_STEREO);
    }
}

void projectmd_native_projectm_render(ProjectMDNativeProjectM *renderer) {
    if (projectmd_native_projectm_is_ready(renderer)) {
        projectm_opengl_render_frame(renderer->handle);
    }
}

void projectmd_native_projectm_set_target_framebuffer(ProjectMDNativeProjectM *renderer, unsigned int framebuffer) {
    if (projectmd_native_projectm_is_ready(renderer)) {
        projectm_opengl_set_target_framebuffer(renderer->handle, framebuffer);
    }
}

