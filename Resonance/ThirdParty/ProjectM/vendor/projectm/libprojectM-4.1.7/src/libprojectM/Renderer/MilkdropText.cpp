/*
  MilkDrop 2 song-title animation compatibility renderer.

  Copyright 2005-2013 Nullsoft, Inc.
  Copyright 2026 Resonance contributors.

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions are met:
  1. Redistributions of source code must retain the above copyright notice,
     this list of conditions and the following disclaimer.
  2. Redistributions in binary form must reproduce the above copyright notice,
     this list of conditions and the following disclaimer in the documentation
     and/or other materials provided with the distribution.
  3. Neither the name of Nullsoft nor the names of its contributors may be used
     to endorse or promote products derived from this software without specific
     prior written permission.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
  AND ANY EXPRESS OR IMPLIED WARRANTIES ARE DISCLAIMED.
*/

#include "MilkdropText.hpp"

#include <algorithm>
#include <array>
#include <cmath>

namespace libprojectM {
namespace Renderer {

#ifdef USE_GLES
static constexpr char ShaderVersion[] = "#version 300 es\n\n";
#else
static constexpr char ShaderVersion[] = "#version 330\n\n";
#endif

static constexpr char VertexShader[] = R"(
precision mediump float;

layout(location = 0) in vec2 position;
layout(location = 1) in vec2 tex_coord;

out vec2 fragment_tex_coord;
uniform vec2 pixel_offset;

void main() {
    gl_Position = vec4(position + pixel_offset, 0.0, 1.0);
    fragment_tex_coord = tex_coord;
}
)";

static constexpr char FragmentShader[] = R"(
precision mediump float;

in vec2 fragment_tex_coord;
uniform sampler2D title_texture;
uniform float intensity;
out vec4 color;

void main() {
    vec3 text_level = texture(title_texture, fragment_tex_coord).rgb * intensity;
    color = vec4(text_level, 1.0);
}
)";

namespace {
constexpr int Columns = 16;
constexpr int Rows = 8;
// Resonance lyric rasterization may wrap a long line to three rows. Sample
// the complete texture so the final wrapped row is not discarded.
constexpr float VerticalClip = 1.0f;
}

MilkdropText::MilkdropText()
{
    RenderItem::Init();

    std::string vertexSource(ShaderVersion);
    vertexSource.append(VertexShader);
    std::string fragmentSource(ShaderVersion);
    fragmentSource.append(FragmentShader);
    m_shader.CompileProgram(vertexSource, fragmentSource);

    std::array<GLushort, (Columns - 1) * (Rows - 1) * 6> indices{};
    size_t index = 0;
    for (int y = 0; y < Rows - 1; ++y)
    {
        for (int x = 0; x < Columns - 1; ++x)
        {
            indices[index++] = static_cast<GLushort>(y * Columns + x);
            indices[index++] = static_cast<GLushort>(y * Columns + x + 1);
            indices[index++] = static_cast<GLushort>((y + 1) * Columns + x);
            indices[index++] = static_cast<GLushort>(y * Columns + x + 1);
            indices[index++] = static_cast<GLushort>((y + 1) * Columns + x);
            indices[index++] = static_cast<GLushort>((y + 1) * Columns + x + 1);
        }
    }

    glBindVertexArray(m_vaoID);
    glGenBuffers(1, &m_indexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, m_indexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices.data(), GL_STATIC_DRAW);
    glBindVertexArray(0);
}

MilkdropText::~MilkdropText()
{
    if (m_indexBuffer != 0)
    {
        glDeleteBuffers(1, &m_indexBuffer);
    }
}

void MilkdropText::InitVertexAttrib()
{
    glEnableVertexAttribArray(0);
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, sizeof(TexturedPoint),
                          reinterpret_cast<void*>(offsetof(TexturedPoint, x)));
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, sizeof(TexturedPoint),
                          reinterpret_cast<void*>(offsetof(TexturedPoint, u)));
    glBufferData(GL_ARRAY_BUFFER, sizeof(TexturedPoint) * Columns * Rows, nullptr, GL_DYNAMIC_DRAW);
}

void MilkdropText::SetTexture(const uint8_t* rgbaPixels, int width, int height)
{
    if (rgbaPixels == nullptr || width <= 0 || height <= 0)
    {
        Clear();
        return;
    }

    m_texture = std::make_shared<Texture>("resonance_lyric", width, height,
                                          GL_RGBA8, GL_RGBA, GL_UNSIGNED_BYTE, false);
    m_texture->Bind(0);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, width, height,
                    GL_RGBA, GL_UNSIGNED_BYTE, rgbaPixels);
    m_texture->Unbind(0);
    m_progress = 0.0f;
    m_burned = false;
}

void MilkdropText::SetProgress(float progress)
{
    if (m_texture == nullptr || m_burned)
    {
        return;
    }
    m_progress = std::clamp(progress, 0.0f, 1.0f);
}

void MilkdropText::Clear()
{
    m_texture.reset();
    m_progress = 0.0f;
    m_burned = true;
}

auto MilkdropText::Progress() const -> float
{
    return m_progress;
}

auto MilkdropText::IsVisible() const -> bool
{
    return m_texture != nullptr && !m_burned && m_progress < 1.0f;
}

auto MilkdropText::ShouldBurnIntoFeedback() const -> bool
{
    return m_texture != nullptr && !m_burned && m_progress >= 1.0f;
}

void MilkdropText::MarkBurned()
{
    m_burned = true;
}

void MilkdropText::Draw(int viewportWidth, int viewportHeight, float time, float progress)
{
    if (m_texture == nullptr || viewportWidth <= 0 || viewportHeight <= 0)
    {
        return;
    }

    const float safeProgress = std::clamp(progress, 0.0001f, 1.0f);
    UpdateMesh(viewportWidth, viewportHeight, time, safeProgress);
    m_texture->Bind(0);
    m_sampler.Bind(0);
    m_shader.Bind();
    m_shader.SetUniformInt("title_texture", 0);

    glEnable(GL_BLEND);
    glBlendEquation(GL_FUNC_ADD);
    glBindVertexArray(m_vaoID);

    const float intensity = std::pow(safeProgress, 0.3f);
    DrawPass(2.0f / static_cast<float>(viewportWidth),
             -2.0f / static_cast<float>(viewportHeight), true, intensity);
    DrawPass(-2.0f / static_cast<float>(viewportWidth),
             2.0f / static_cast<float>(viewportHeight), false, intensity);

    glBindVertexArray(0);
    glDisable(GL_BLEND);
    Shader::Unbind();
    m_texture->Unbind(0);
    Sampler::Unbind(0);
}

void MilkdropText::UpdateMesh(int viewportWidth, int viewportHeight, float time, float progress)
{
    std::array<TexturedPoint, Columns * Rows> vertices{};
    const float textureAspect = static_cast<float>(m_texture->Height()) /
                                static_cast<float>(m_texture->Width());
    const float viewportAspect = static_cast<float>(viewportWidth) /
                                 static_cast<float>(viewportHeight);
    // Resonance displays synced lyrics over the visualization. The wider
    // raster canvas gives long lines more layout room, while this band uses
    // approximately 80% of the visualization width. The full vertical
    // texture range below preserves every wrapped lyric row, including three
    // full lines when the rasterizer wraps a long verse.
    const float sizeX = 0.80f;
    const float sizeY = std::min(0.88f, sizeX * textureAspect * viewportAspect);

    for (int y = 0; y < Rows; ++y)
    {
        for (int x = 0; x < Columns; ++x)
        {
            auto& vertex = vertices[static_cast<size_t>(y * Columns + x)];
            vertex.u = static_cast<float>(x) / static_cast<float>(Columns - 1);
            vertex.v = (static_cast<float>(y) / static_cast<float>(Rows - 1) - 0.5f) *
                       VerticalClip + 0.5f;
            vertex.x = (vertex.u * 2.0f - 1.0f) * sizeX;
            vertex.y = (vertex.v * 2.0f - 1.0f) * sizeY;
        }
    }

    // Original MilkDrop 2 song-title mesh warp.
    const float rampedProgress = std::max(0.0f, 1.0f - progress * 1.5f);
    const float t2 = std::pow(rampedProgress, 1.8f) * 1.3f;
    for (auto& vertex : vertices)
    {
        vertex.x += t2 * 0.070f * std::sin(time * 0.31f + vertex.x * 0.39f - vertex.y * 1.94f);
        vertex.x += t2 * 0.044f * std::sin(time * 0.81f - vertex.x * 1.91f + vertex.y * 0.27f);
        vertex.x += t2 * 0.061f * std::sin(time * 1.31f + vertex.x * 0.61f + vertex.y * 0.74f);
        vertex.y += t2 * 0.061f * std::sin(time * 0.37f + vertex.x * 1.83f + vertex.y * 0.69f);
        vertex.y += t2 * 0.070f * std::sin(time * 0.67f + vertex.x * 0.42f - vertex.y * 1.39f);
        vertex.y += t2 * 0.087f * std::sin(time * 1.07f + vertex.x * 3.55f + vertex.y * 0.89f);
    }

    // The original title animation zooms dramatically at progress ~= 0. That
    // is appropriate for a song title entering from off-screen, but it can
    // hide the end of a synced lyric line. Preserve the fade/warp while
    // preventing the fitted lyric mesh from leaving the visible band.
    const float scale = std::min(1.0f, 1.01f / (std::pow(progress, 0.21f) + 0.01f));
    for (auto& vertex : vertices)
    {
        vertex.x *= scale;
        vertex.y *= scale;
    }

    glBindBuffer(GL_ARRAY_BUFFER, m_vboID);
    glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(vertices), vertices.data());
    glBindBuffer(GL_ARRAY_BUFFER, 0);
}

void MilkdropText::DrawPass(float offsetX, float offsetY, bool shadowPass, float intensity)
{
    m_shader.SetUniformFloat2("pixel_offset", {offsetX, offsetY});
    m_shader.SetUniformFloat("intensity", intensity);
    glBlendFunc(shadowPass ? GL_ZERO : GL_ONE,
                shadowPass ? GL_ONE_MINUS_SRC_COLOR : GL_ONE);
    glDrawElements(GL_TRIANGLES, (Columns - 1) * (Rows - 1) * 6,
                   GL_UNSIGNED_SHORT, nullptr);
}

} // namespace Renderer
} // namespace libprojectM
