/*
  MilkDrop 2 song-title animation compatibility renderer.

  The mesh shape, progress curves, two-pass blending, and feedback-burn
  behavior are adapted from MilkDrop 2.25c milkdropfs.cpp, Copyright
  2005-2013 Nullsoft, Inc., under its three-clause BSD license.
*/
#pragma once

#include "Renderer/RenderItem.hpp"
#include "Renderer/Sampler.hpp"
#include "Renderer/Shader.hpp"
#include "Renderer/Texture.hpp"

#include <cstdint>
#include <memory>

namespace libprojectM {
namespace Renderer {

class MilkdropText : public RenderItem
{
public:
    MilkdropText();
    ~MilkdropText() override;

    void InitVertexAttrib() override;

    void SetTexture(const uint8_t* rgbaPixels, int width, int height);
    void SetProgress(float progress);
    void Clear();

    auto Progress() const -> float;
    auto IsVisible() const -> bool;
    auto ShouldBurnIntoFeedback() const -> bool;
    void MarkBurned();

    void Draw(int viewportWidth, int viewportHeight, float time, float progress);

private:
    void UpdateMesh(int viewportWidth, int viewportHeight, float time, float progress);
    void DrawPass(float offsetX, float offsetY, bool shadowPass, float intensity);

    Shader m_shader;
    Sampler m_sampler{GL_CLAMP_TO_EDGE, GL_LINEAR};
    std::shared_ptr<Texture> m_texture;
    GLuint m_indexBuffer{};
    float m_progress{};
    bool m_burned{true};
};

} // namespace Renderer
} // namespace libprojectM
