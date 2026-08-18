#ifndef PROJECT_MD_NATIVE_PROJECTM_BRIDGE_H
#define PROJECT_MD_NATIVE_PROJECTM_BRIDGE_H

#include <stdbool.h>
#include <stddef.h>

typedef struct ProjectMDNativeProjectM ProjectMDNativeProjectM;

#ifdef __cplusplus
extern "C" {
#endif

ProjectMDNativeProjectM *projectmd_native_projectm_create(void);
void projectmd_native_projectm_destroy(ProjectMDNativeProjectM *renderer);
bool projectmd_native_projectm_is_ready(const ProjectMDNativeProjectM *renderer);
const char *projectmd_native_projectm_last_error(const ProjectMDNativeProjectM *renderer);
void projectmd_native_projectm_set_window_size(ProjectMDNativeProjectM *renderer, size_t width, size_t height);
void projectmd_native_projectm_set_texture_path(ProjectMDNativeProjectM *renderer, const char *path);
void projectmd_native_projectm_set_texture_paths(ProjectMDNativeProjectM *renderer, const char *primaryPath, const char *secondaryPath);
bool projectmd_native_projectm_load_preset_file(ProjectMDNativeProjectM *renderer, const char *path, bool smooth_transition);
bool projectmd_native_projectm_load_preset_data(ProjectMDNativeProjectM *renderer, const char *data, bool smooth_transition);
void projectmd_native_projectm_add_stereo_pcm(ProjectMDNativeProjectM *renderer, const float *samples, size_t frame_count);
void projectmd_native_projectm_render(ProjectMDNativeProjectM *renderer);
void projectmd_native_projectm_set_target_framebuffer(ProjectMDNativeProjectM *renderer, unsigned int framebuffer);

#ifdef __cplusplus
}
#endif

#endif

