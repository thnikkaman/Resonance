#!/bin/sh
set -eu

# Builds the vendored projectM OpenGL ES implementation as an app-local static
# archive. This deliberately excludes projectm-eval: the app owns that C
# component already, and archiving it again would create duplicate symbols.

: "${SRCROOT:?SRCROOT is required}"
: "${DERIVED_FILE_DIR:?DERIVED_FILE_DIR is required}"
: "${SDKROOT:?SDKROOT is required}"
: "${ARCHS:?ARCHS is required}"
: "${IPHONEOS_DEPLOYMENT_TARGET:?IPHONEOS_DEPLOYMENT_TARGET is required}"
: "${CONFIGURATION:?CONFIGURATION is required}"

repo_root="$SRCROOT"
projectm_root="$repo_root/Resonance/ThirdParty/ProjectM/vendor/projectm/libprojectM-4.1.7"
build_root="$DERIVED_FILE_DIR/projectm-native"
generated_root="$build_root/generated"
object_root="$build_root/objects"
include_root="$generated_root/include"
archive="$DERIVED_FILE_DIR/libprojectM-ios.a"

rm -rf "$build_root"
mkdir -p "$include_root/projectM-4" "$generated_root/milkdrop" "$generated_root/renderer" "$object_root"

cat > "$include_root/projectM-4/projectM_export.h" <<'EOF'
#pragma once
#define PROJECTM_EXPORT
#define PROJECTM_NO_EXPORT
#define PROJECTM_DEPRECATED
#define PROJECTM_DEPRECATED_EXPORT
#define PROJECTM_DEPRECATED_NO_EXPORT
#define PROJECTM_NO_DEPRECATED
#define PROJECTM_NO_DEPRECATED_WARNINGS
EOF

cat > "$include_root/projectM-4/version.h" <<'EOF'
#pragma once
#define PROJECTM_VERSION_MAJOR 4
#define PROJECTM_VERSION_MINOR 1
#define PROJECTM_VERSION_PATCH 7
#define PROJECTM_VERSION_STRING "4.1.7"
#define PROJECTM_VERSION_VCS "vendored"
EOF

shader_contents_file="$build_root/shader-contents"
shader_declarations_file="$build_root/shader-declarations"
shader_definitions_file="$build_root/shader-definitions"
: > "$shader_contents_file"
: > "$shader_declarations_file"
: > "$shader_definitions_file"
for shader in "$projectm_root"/src/libprojectM/MilkdropPreset/Shaders/*; do
    [ -f "$shader" ] || continue
    name=$(basename "$shader")
    stem=${name%.*}
    accessor=$(printf '%s' "$stem" | sed 's/Glsl[0-9]*//')
    {
        printf 'static std::string k%s = R"(\n' "$stem"
        cat "$shader"
        printf ')";\n\n'
    } >> "$shader_contents_file"
    if printf '%s' "$name" | grep -q '\.inc$'; then
        # Include fragments are already complete GLSL snippets.  The upstream
        # generator therefore exposes them without the common shader header.
        printf 'DECLARE_SHADER_ACCESSOR_NO_HEADER(%s);\n' "$accessor" >> "$shader_definitions_file"
    else
        printf 'DECLARE_SHADER_ACCESSOR(%s);\n' "$accessor" >> "$shader_definitions_file"
    fi
    printf '    std::string Get%s();\n' "$accessor" >> "$shader_declarations_file"
done

awk -v contents="$shader_contents_file" -v declarations="$shader_declarations_file" '
    /@STATIC_SHADER_CONTENTS@/ { while ((getline line < contents) > 0) print line; next }
    /@STATIC_SHADER_ACCESSOR_DECLARATIONS@/ { while ((getline line < declarations) > 0) print line; next }
    { print }
' "$projectm_root/src/libprojectM/MilkdropPreset/MilkdropStaticShaders.hpp.in" \
    > "$generated_root/milkdrop/MilkdropStaticShaders.hpp"
awk -v contents="$shader_contents_file" -v definitions="$shader_definitions_file" '
    /@STATIC_SHADER_CONTENTS@/ { while ((getline line < contents) > 0) print line; next }
    /@STATIC_SHADER_ACCESSOR_DEFINITIONS@/ {
        while ((getline line < definitions) > 0) print line
        next
    }
    { print }
' "$projectm_root/src/libprojectM/MilkdropPreset/MilkdropStaticShaders.cpp.in" \
    > "$generated_root/milkdrop/MilkdropStaticShaders.cpp"

transition_contents_file="$build_root/transition-contents"
: > "$transition_contents_file"
for shader in "$projectm_root"/src/libprojectM/Renderer/TransitionShaders/*; do
    [ -f "$shader" ] || continue
    name=$(basename "$shader")
    stem=${name%.*}
    {
        printf 'static std::string k%s = R"(\n' "$stem"
        cat "$shader"
        printf ')";\n\n'
    } >> "$transition_contents_file"
done
awk -v contents="$transition_contents_file" \
    '/@STATIC_SHADER_CONTENTS@/ { while ((getline line < contents) > 0) print line; next } { print }' \
    "$projectm_root/src/libprojectM/Renderer/BuiltInTransitionsResources.hpp.in" \
    > "$generated_root/renderer/BuiltInTransitionsResources.hpp"

config="$build_root/projectm-config.h"
cat > "$config" <<'EOF'
#pragma once
#define USE_GLES 1
#define PROJECTM_STATIC_DEFINE 1
#define PROJECTM_FILESYSTEM_NAMESPACE std
#define PROJECTM_FILESYSTEM_INCLUDE <filesystem>
#define DATADIR_PATH "."
EOF

if printf '%s' "$SDKROOT" | grep -q 'iPhoneSimulator'; then
    platform_min_flag="-mios-simulator-version-min=$IPHONEOS_DEPLOYMENT_TARGET"
else
    platform_min_flag="-miphoneos-version-min=$IPHONEOS_DEPLOYMENT_TARGET"
fi
case "$CONFIGURATION" in
    Release)
        optimization_flags="-O3 -DNDEBUG"
        ;;
    *)
        optimization_flags="-O0 -g"
        ;;
esac

# Xcode supplies multiple architectures as a space-separated value for the
# simulator. Expand each one into its own clang option instead of handing the
# whole list to a single -arch flag.
arch_flags=""
for arch in $ARCHS; do
    arch_flags="$arch_flags -arch $arch"
done

# This script invokes clang directly, outside Xcode's normal Compile Sources
# phase, so Xcode's configuration-specific optimization flags are not applied
# automatically. Keep the vendored renderer optimized in Release builds;
# projectM performs substantial C/C++ preset evaluation work every frame.
common_flags="-isysroot $SDKROOT $arch_flags $platform_min_flag $optimization_flags -std=c++17 -include $config -DUSE_GLES -DPROJECTM_STATIC_DEFINE -DGLES_SILENCE_DEPRECATION"
c_common_flags="-isysroot $SDKROOT $arch_flags $platform_min_flag $optimization_flags -include $config -DUSE_GLES -DPROJECTM_STATIC_DEFINE -DGLES_SILENCE_DEPRECATION"
includes="-I$include_root -I$generated_root/milkdrop -I$generated_root/renderer -I$projectm_root/src -I$projectm_root/src/api/include -I$projectm_root/src/libprojectM -I$projectm_root/src/libprojectM/MilkdropPreset -I$projectm_root/src/libprojectM/MilkdropPreset/Waveforms -I$projectm_root/src/libprojectM/Renderer -I$projectm_root/src/libprojectM/Audio -I$projectm_root/vendor -I$projectm_root/vendor/hlslparser/src -I$projectm_root/vendor/SOIL2 -I$projectm_root/vendor/projectm-eval -I$projectm_root/vendor/projectm-eval/projectm-eval -I$projectm_root/vendor/projectm-eval/projectm-eval/api"

objects=""
compile_cpp() {
    source="$1"
    base=$(printf '%s' "$source" | sed "s|$projectm_root/||; s|[^A-Za-z0-9]|_|g")
    object="$object_root/${base}.o"
    xcrun clang++ $common_flags $includes -c "$source" -o "$object"
    objects="$objects $object"
}
compile_c() {
    source="$1"
    base=$(printf '%s' "$source" | sed "s|$projectm_root/||; s|[^A-Za-z0-9]|_|g")
    object="$object_root/${base}.o"
    xcrun clang $c_common_flags -x c $includes -c "$source" -o "$object"
    objects="$objects $object"
}

compile_cpp "$generated_root/milkdrop/MilkdropStaticShaders.cpp"
find "$projectm_root/vendor/hlslparser/src" -type f -name '*.cpp' -print | sort | while IFS= read -r source; do compile_cpp "$source"; done
find "$projectm_root/src/libprojectM" -type f -name '*.cpp' -print | sort | while IFS= read -r source; do compile_cpp "$source"; done
find "$projectm_root/vendor/SOIL2" -maxdepth 1 -type f -name '*.c' -print | sort | while IFS= read -r source; do compile_c "$source"; done

# The functions above run in subshells when fed by a pipeline, so collect the
# objects directly for archiving rather than relying on the local accumulator.
find "$object_root" -type f -name '*.o' -print | sort > "$build_root/object-list"
# clang emits universal objects when Xcode supplies multiple simulator
# architectures. Apple's libtool archives those objects correctly; ar rejects
# them as "fat files".
xargs /usr/bin/libtool -static -o "$archive" < "$build_root/object-list"
