#include "TransitionShaderManager.hpp"

#include "BuiltInTransitionsResources.hpp"

#include <iostream>

#include <array>

namespace libprojectM {
namespace Renderer {

TransitionShaderManager::TransitionShaderManager()
    : m_mersenneTwister(m_randomDevice())
{
    const std::array<std::string, 6> transitionSources = {
        // Keep the deterministic crossfade first: it is also the GLES
        // fallback used on iOS, where the more elaborate randomized effects
        // can produce intermittent partial/slanted composites despite clean
        // GL state.
        kTransitionShaderBuiltInSimpleBlendGlsl330,
        kTransitionShaderBuiltInCircleGlsl330,
        kTransitionShaderBuiltInPlasmaGlsl330,
        kTransitionShaderBuiltInSweepGlsl330,
        kTransitionShaderBuiltInWarpGlsl330,
        kTransitionShaderBuiltInZoomBlurGlsl330
    };

    for (const auto& source : transitionSources) {
        if (auto shader = CompileTransitionShader(source)) {
            m_transitionShaders.push_back(shader);
        }
    }

    if (!m_transitionShaders.empty()) {
        m_fallbackTransitionShader = m_transitionShaders.front();
    }
}

auto TransitionShaderManager::RandomTransition() -> std::shared_ptr<Shader>
{
#ifdef USE_GLES
    return m_fallbackTransitionShader;
#else
    if (m_transitionShaders.empty())
    {
        return m_fallbackTransitionShader;
    }

    return m_transitionShaders.at(m_mersenneTwister() % m_transitionShaders.size());
#endif
}

auto TransitionShaderManager::CompileTransitionShader(const std::string& shaderBodyCode) -> std::shared_ptr<Shader>
{
#ifdef USE_GLES
    // GLES also requires a precision specifier for variables and 3D samplers
    constexpr char versionHeader[] = "#version 300 es\n\nprecision mediump float;\nprecision mediump sampler3D;\n";
#else
    constexpr char versionHeader[] = "#version 330\n\n";
#endif

    std::string fragmentShaderSource(static_cast<const char*>(versionHeader));
    fragmentShaderSource.append(kTransitionShaderHeaderGlsl330);
    fragmentShaderSource.append("\n");
    fragmentShaderSource.append(shaderBodyCode);
    fragmentShaderSource.append("\n");
    fragmentShaderSource.append(kTransitionShaderMainGlsl330);

    try
    {
        auto transitionShader = std::make_shared<Shader>();
        transitionShader->CompileProgram(static_cast<const char*>(versionHeader) + kTransitionVertexShaderGlsl330, fragmentShaderSource);
        return transitionShader;
    }
    catch (const ShaderException&)
    {
        // ToDo: Log proper shader compile error once logging API is in place
        return {};
    }
}

} // namespace Renderer
} // namespace libprojectM
