/**
* projectM -- Milkdrop-esque visualisation SDK
* Copyright (C)2003-2004 projectM Team
*
* This library is free software; you can redistribute it and/or
* modify it under the terms of the GNU Lesser General Public
* License as published by the Free Software Foundation; either
* version 2.1 of the License, or (at your option) any later version.
*
* This library is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* Lesser General Public License for more details.
*
* You should have received a copy of the GNU Lesser General Public
* License along with this library; if not, write to the Free Software
* Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
* See 'LICENSE.txt' included within this release
*
*/

#include "ProjectM.hpp"

#include "Preset.hpp"
#include "PresetFactoryManager.hpp"
#include "TimeKeeper.hpp"

#include <Audio/PCM.hpp>

#ifdef USE_GLES
#include <projectM-opengl.h>
#endif

#include <Renderer/CopyTexture.hpp>
#include <Renderer/Framebuffer.hpp>
#include <Renderer/MilkdropText.hpp>
#include <Renderer/PresetTransition.hpp>
#include <Renderer/TextureManager.hpp>
#include <Renderer/TransitionShaderManager.hpp>

namespace libprojectM {

#ifdef USE_GLES
static auto ClearOpenGLErrors() -> GLenum
{
    GLenum lastError = GL_NO_ERROR;
    GLenum error = GL_NO_ERROR;
    while ((error = glGetError()) != GL_NO_ERROR)
    {
        lastError = error;
    }
    return lastError;
}

#endif

ProjectM::ProjectM()
    : m_presetFactoryManager(std::make_unique<PresetFactoryManager>())
{
    Initialize();
}

ProjectM::~ProjectM()
{
    // Can't use "=default" in the header due to unique_ptr requiring the actual type declarations.
}

void ProjectM::PresetSwitchRequestedEvent(bool) const
{
}

void ProjectM::PresetSwitchFailedEvent(const std::string&, const std::string&) const
{
}

void ProjectM::LoadPresetFile(const std::string& presetFilename, bool smoothTransition)
{
    try
    {
        m_textureManager->PurgeTextures();
        StartPresetTransition(m_presetFactoryManager->CreatePresetFromFile(presetFilename), !smoothTransition);
    }
    catch (const std::exception& ex)
    {
        PresetSwitchFailedEvent(presetFilename, ex.what());
    }
}

void ProjectM::LoadPresetData(std::istream& presetData, bool smoothTransition)
{
    try
    {
        m_textureManager->PurgeTextures();
        StartPresetTransition(m_presetFactoryManager->CreatePresetFromStream(".milk", presetData), !smoothTransition);
    }
    catch (const std::exception& ex)
    {
        PresetSwitchFailedEvent("", ex.what());
    }
}

void ProjectM::SetTexturePaths(std::vector<std::string> texturePaths)
{
    m_textureSearchPaths = std::move(texturePaths);
    m_textureManager = std::make_unique<Renderer::TextureManager>(m_textureSearchPaths);
}

void ProjectM::ResetTextures()
{
    m_textureManager = std::make_unique<Renderer::TextureManager>(m_textureSearchPaths);
}

void ProjectM::RenderFrame()
{
    // Don't render if window area is zero.
    if (m_windowWidth == 0 || m_windowHeight == 0)
    {
        return;
    }

    // Update FPS and other timer values.
    m_timeKeeper->UpdateTimers();

    // Update and retrieve audio data
    m_audioStorage.UpdateFrameAudioData(m_timeKeeper->SecondsSinceLastFrame(), m_frameCount);
    auto audioData = m_audioStorage.GetFrameAudioData();

    // Check if the preset isn't locked, and we've not already notified the user
    if (!m_presetChangeNotified)
    {
        // If preset is done and we're not already switching
        if (m_timeKeeper->PresetProgressA() >= 1.0 && !m_timeKeeper->IsSmoothing())
        {
            m_presetChangeNotified = true;
            PresetSwitchRequestedEvent(false);
        }
        else if (m_hardCutEnabled &&
                 m_frameCount > 50 &&
                 (audioData.vol - m_previousFrameVolume > m_hardCutSensitivity) &&
                 m_timeKeeper->CanHardCut())
        {
            m_presetChangeNotified = true;
            PresetSwitchRequestedEvent(true);
        }
    }

    // If no preset is active, load the idle preset.
    if (!m_activePreset)
    {
        LoadIdlePreset();
        if (!m_activePreset)
        {
            return;
        }

        m_activePreset->Initialize(GetRenderContext());
    }

    if (m_timeKeeper->IsSmoothing() && m_transitioningPreset != nullptr)
    {
        // ToDo: check if new preset is loaded.

        if (m_timeKeeper->SmoothRatio() >= 1.0)
        {
            m_timeKeeper->EndSmoothing();
        }
    }

    auto renderContext = GetRenderContext();
    if (m_holdOutgoingFrame && m_milkdropText->ShouldBurnIntoFeedback())
    {
        // The destination preset is intentionally not rendered on the held
        // outgoing frame. Defer the one-time burn until both presets render,
        // so the lyric survives either side of the transition.
        renderContext.milkdropText = nullptr;
    }

    if (m_transition != nullptr && m_transitioningPreset != nullptr)
    {
        if (m_transition->IsDone())
        {
            m_activePreset = std::move(m_transitioningPreset);
            m_transitioningPreset.reset();
            m_transition.reset();
        }
        else if (!m_holdOutgoingFrame)
        {
            m_transitioningPreset->RenderFrame(audioData, renderContext);
        }
    }


    // ToDo: Call the to-be-implemented render method in Renderer
    m_activePreset->RenderFrame(audioData, renderContext);

    // Compose the complete frame away from the GLKView drawable. On iOS the
    // drawable is a tile-based presentation surface; drawing a transition
    // directly into it can expose a partially updated tile set even when all
    // framebuffer state and GL error checks are clean. Present only after the
    // full transition result exists in the app-owned offscreen texture.
    m_outputFramebuffer->SetSize(renderContext.viewportSizeX, renderContext.viewportSizeY);
    m_outputFramebuffer->Bind(0);
    glViewport(0, 0, renderContext.viewportSizeX, renderContext.viewportSizeY);

#ifdef USE_GLES
    GLenum drawBuffer = GL_COLOR_ATTACHMENT0;
    glDrawBuffers(1, &drawBuffer);
#endif

    if (m_transition != nullptr && m_transitioningPreset != nullptr)
    {
        if (m_holdOutgoingFrame)
        {
            // Keep the outgoing image visible for one complete display frame
            // outside the transition shader and texture-sampling path.
            m_textureCopier->Draw(m_activePreset->OutputTexture(), false, false);
            m_holdOutgoingFrame = false;
            // Start the transition clock only after one complete outgoing
            // frame has reached the offscreen composite. This prevents load
            // time and the button's SwiftUI update from consuming the first
            // transition sample before the display has presented it.
            m_transition->Restart();
        }
#ifdef USE_GLES
        else
        {
        // A newly loaded preset can leave one of its first internal GLES
        // passes with an incomplete framebuffer on iOS. Do not expose the
        // resulting partial/slanted composite. The new preset has already
        // rendered into its own output texture, so use that clean texture for
        // this frame and let the transition resume on the next frame.
        const auto renderError = ClearOpenGLErrors();
        if (renderError != GL_NO_ERROR)
        {
            // A failed transition composite must preserve the outgoing image.
            // Copying the incoming texture here is the visible one-frame flash
            // reported on the phone.
            m_textureCopier->Draw(m_activePreset->OutputTexture(), false, false);
        }
        else
        {
            m_transition->Draw(*m_activePreset, *m_transitioningPreset, renderContext, audioData);
            const auto transitionError = ClearOpenGLErrors();
            if (transitionError != GL_NO_ERROR)
            {
                m_textureCopier->Draw(m_activePreset->OutputTexture(), false, false);
            }
        }
        }
#else
        else
        {
            m_transition->Draw(*m_activePreset, *m_transitioningPreset, renderContext, audioData);
        }
#endif
    }
    else
    {
        m_textureCopier->Draw(m_activePreset->OutputTexture(), false, false);
    }

    // During the active title animation, MilkDrop 2 drew the text mesh after
    // the final composite so it stayed legible. Completion is handled inside
    // MilkdropPreset above, where the same mesh is burned into feedback.
    if (m_milkdropText->IsVisible())
    {
        m_outputFramebuffer->Bind(0);
        glViewport(0, 0, renderContext.viewportSizeX, renderContext.viewportSizeY);
#ifdef USE_GLES
        drawBuffer = GL_COLOR_ATTACHMENT0;
        glDrawBuffers(1, &drawBuffer);
#endif
        m_milkdropText->Draw(renderContext.viewportSizeX,
                             renderContext.viewportSizeY,
                             renderContext.time,
                             m_milkdropText->Progress());
    }

    // Make exactly one complete-frame copy into the presentation drawable.
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, m_targetFramebuffer);
    glViewport(0, 0, renderContext.viewportSizeX, renderContext.viewportSizeY);
#ifdef USE_GLES
    drawBuffer = m_targetFramebuffer == 0 ? GL_BACK : GL_COLOR_ATTACHMENT0;
    glDrawBuffers(1, &drawBuffer);
#endif
    m_textureCopier->Draw(m_outputFramebuffer->GetColorAttachmentTexture(0, 0), false, false);

    if (renderContext.milkdropText != nullptr &&
        m_milkdropText->ShouldBurnIntoFeedback())
    {
        m_milkdropText->MarkBurned();
    }

    m_frameCount++;
    m_previousFrameVolume = audioData.vol;
}

void ProjectM::SetTargetFramebuffer(unsigned int framebuffer)
{
    m_targetFramebuffer = framebuffer;
}

void ProjectM::SetLyricTexture(const uint8_t* rgbaPixels, int width, int height)
{
    m_milkdropText->SetTexture(rgbaPixels, width, height);
}

void ProjectM::SetLyricProgress(float progress)
{
    m_milkdropText->SetProgress(progress);
}

void ProjectM::ClearLyricTexture()
{
    m_milkdropText->Clear();
}

void ProjectM::Initialize()
{
    /** Initialise start time */
    m_timeKeeper = std::make_unique<TimeKeeper>(m_presetDuration,
                                                m_softCutDuration,
                                                m_hardCutDuration,
                                                m_easterEgg);

    /** Nullify frame stash */

    /** Initialise per-pixel matrix calculations */
    /** We need to initialise this before the builtin param db otherwise bass/mid etc won't bind correctly */
    m_textureManager = std::make_unique<Renderer::TextureManager>(m_textureSearchPaths);

    m_transitionShaderManager = std::make_unique<Renderer::TransitionShaderManager>();

    m_textureCopier = std::make_unique<Renderer::CopyTexture>();
    m_outputFramebuffer = std::make_unique<Renderer::Framebuffer>();
    m_outputFramebuffer->CreateColorAttachment(0, 0);
    m_milkdropText = std::make_unique<Renderer::MilkdropText>();

    m_presetFactoryManager->initialize();

    /* Set the seed to the current time in seconds */
    srand(time(nullptr));

    LoadIdlePreset();

    m_timeKeeper->StartPreset();
}

void ProjectM::LoadIdlePreset()
{
    LoadPresetFile("idle://Geiss & Sperl - Feedback (projectM idle HDR mix).milk", false);
    assert(m_activePreset);
}

void ProjectM::SetWindowSize(uint32_t width, uint32_t height)
{
    /** Stash the new dimensions */
    m_windowWidth = width;
    m_windowHeight = height;
}

void ProjectM::StartPresetTransition(std::unique_ptr<Preset>&& preset, bool hardCut)
{
    m_presetChangeNotified = m_presetLocked;

    if (preset == nullptr)
    {
        return;
    }

    preset->Initialize(GetRenderContext());

    // If already in a transition, force immediate completion.
    if (m_transitioningPreset != nullptr)
    {
        m_activePreset = std::move(m_transitioningPreset);
        m_transition.reset();
    }

    if (m_activePreset)
    {
        preset->DrawInitialImage(m_activePreset->OutputTexture(), GetRenderContext());
    }

    if (hardCut)
    {
        m_activePreset = std::move(preset);
        m_timeKeeper->StartPreset();
    }
    else
    {
        m_transitioningPreset = std::move(preset);
        m_timeKeeper->StartSmoothing();
        m_transition = std::make_unique<Renderer::PresetTransition>(m_transitionShaderManager->RandomTransition(), m_softCutDuration);
        m_holdOutgoingFrame = true;
    }
}

auto ProjectM::WindowWidth() -> int
{
    return m_windowWidth;
}

auto ProjectM::WindowHeight() -> int
{
    return m_windowHeight;
}

void ProjectM::SetPresetLocked(bool locked)
{
    // ToDo: Add a preset switch timer separate from the display timer and reset to 0 when
    //       disabling the preset switch lock.
    m_presetLocked = locked;
    m_presetChangeNotified = locked;
}

auto ProjectM::PresetLocked() const -> bool
{
    return m_presetLocked;
}

void ProjectM::SetBeatSensitivity(float sensitivity)
{
    m_beatSensitivity = std::min(std::max(0.0f, sensitivity), 2.0f);
}

auto ProjectM::GetBeatSensitivity() const -> float
{
    return m_beatSensitivity;
}

auto ProjectM::SoftCutDuration() const -> double
{
    return m_softCutDuration;
}

void ProjectM::SetSoftCutDuration(double seconds)
{
    m_softCutDuration = seconds;
    m_timeKeeper->ChangeSoftCutDuration(seconds);
}

auto ProjectM::HardCutDuration() const -> double
{
    return m_hardCutDuration;
}

void ProjectM::SetHardCutDuration(double seconds)
{
    m_hardCutDuration = static_cast<int>(seconds);
    m_timeKeeper->ChangeHardCutDuration(seconds);
}

auto ProjectM::HardCutEnabled() const -> bool
{
    return m_hardCutEnabled;
}

void ProjectM::SetHardCutEnabled(bool enabled)
{
    m_hardCutEnabled = enabled;
}

auto ProjectM::HardCutSensitivity() const -> float
{
    return m_hardCutSensitivity;
}

void ProjectM::SetHardCutSensitivity(float sensitivity)
{
    m_hardCutSensitivity = sensitivity;
}

void ProjectM::SetPresetDuration(double seconds)
{
    m_timeKeeper->ChangePresetDuration(seconds);
}

auto ProjectM::PresetDuration() const -> double
{
    return m_timeKeeper->PresetDuration();
}

auto ProjectM::TargetFramesPerSecond() const -> int32_t
{
    return m_targetFps;
}

void ProjectM::SetTargetFramesPerSecond(int32_t fps)
{
    m_targetFps = fps;
}

auto ProjectM::AspectCorrection() const -> bool
{
    return m_aspectCorrection;
}

void ProjectM::SetAspectCorrection(bool enabled)
{
    m_aspectCorrection = enabled;
}

auto ProjectM::EasterEgg() const -> float
{
    return m_easterEgg;
}

void ProjectM::SetEasterEgg(float value)
{
    m_easterEgg = value;
    m_timeKeeper->ChangeEasterEgg(value);
}

void ProjectM::MeshSize(uint32_t& meshResolutionX, uint32_t& meshResolutionY) const
{
    meshResolutionX = m_meshX;
    meshResolutionY = m_meshY;
}

void ProjectM::SetMeshSize(uint32_t meshResolutionX, uint32_t meshResolutionY)
{
    m_meshX = meshResolutionX;
    m_meshY = meshResolutionY;

    // Need multiples of two, otherwise will not render a horizontal and/or vertical bar in the center of the warp mesh.
    if (m_meshX % 2 == 1)
    {
        m_meshX++;
    }

    if (m_meshY % 2 == 1)
    {
        m_meshY++;
    }

    // Constrain per-pixel mesh size to sensible limits
    m_meshX = std::max(8u, std::min(400u, m_meshX));
    m_meshY = std::max(8u, std::min(400u, m_meshY));
}

auto ProjectM::PCM() -> libprojectM::Audio::PCM&
{
    return m_audioStorage;
}

void ProjectM::Touch(float, float, int, int)
{
    // UNIMPLEMENTED
}

void ProjectM::TouchDrag(float, float, int)
{
    // UNIMPLEMENTED
}

void ProjectM::TouchDestroy(float, float)
{
    // UNIMPLEMENTED
}

void ProjectM::TouchDestroyAll()
{
    // UNIMPLEMENTED
}

auto ProjectM::GetRenderContext() -> Renderer::RenderContext
{
    Renderer::RenderContext ctx{};
    ctx.viewportSizeX = m_windowWidth;
    ctx.viewportSizeY = m_windowHeight;
    ctx.time = static_cast<float>(m_timeKeeper->GetRunningTime());
    ctx.progress = static_cast<float>(m_timeKeeper->PresetProgressA());
    ctx.fps = static_cast<float>(m_targetFps);
    ctx.frame = m_frameCount;
    ctx.aspectX = (m_windowHeight > m_windowWidth) ? static_cast<float>(m_windowWidth) / static_cast<float>(m_windowHeight) : 1.0f;
    ctx.aspectY = (m_windowWidth > m_windowHeight) ? static_cast<float>(m_windowHeight) / static_cast<float>(m_windowWidth) : 1.0f;
    ctx.invAspectX = 1.0f / ctx.aspectX;
    ctx.invAspectY = 1.0f / ctx.aspectY;
    ctx.perPixelMeshX = static_cast<int>(m_meshX);
    ctx.perPixelMeshY = static_cast<int>(m_meshY);
    ctx.textureManager = m_textureManager.get();
    ctx.milkdropText = m_milkdropText.get();

    return ctx;
}

} // namespace libprojectM
