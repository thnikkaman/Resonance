# projectM iOS build

This directory contains the official projectM 4.x static library packaged for
Resonance as an XCFramework. The library is built with OpenGL ES enabled.

iOS and the iOS simulator expose OpenGL ES 3.0 / GLSL ES 3.00. The upstream
projectM `GladLoader` default check requires GLES 3.2 / GLSL ES 3.20, so the
iOS build must lower only that capability gate to 3.0. The bundled bridge also
provides an iOS OpenGL symbol resolver through the OpenGLES framework.

The upstream library remains LGPL-2.1; see `licenses/projectM-LGPL-2.1.txt`.
