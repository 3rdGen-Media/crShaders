setlocal
cd /d %~dp0

START /WAIT cmd /c C:/3rdGen/CoreRender/bin/x64/crShadersd.exe cr_gbuffer.es2.vert.glsl
START /WAIT cmd /c C:/3rdGen/CoreRender/bin/x64/crShadersd.exe cr_gbuffer.es2.frag.glsl
START /WAIT cmd /c C:/3rdGen/CoreRender/bin/x64/crShadersd.exe cr_mesh_vbo.es2.vert.glsl
START /WAIT cmd /c C:/3rdGen/CoreRender/bin/x64/crShadersd.exe cr_mesh_vbo.es2.frag.glsl
START /WAIT cmd /c C:/3rdGen/CoreRender/bin/x64/crShadersd.exe cr_environment.es2.vert.glsl
START /WAIT cmd /c C:/3rdGen/CoreRender/bin/x64/crShadersd.exe cr_environment.es2.frag.glsl
START /WAIT cmd /c C:/3rdGen/CoreRender/bin/x64/crShadersd.exe cr_atm_transmittance.es2.frag.glsl
START /WAIT cmd /c C:/3rdGen/CoreRender/bin/x64/crShadersd.exe cr_atm_scattering.es2.frag.glsl
START /WAIT cmd /c C:/3rdGen/CoreRender/bin/x64/crShadersd.exe cr_atm_sky_view.es2.frag.glsl

START /WAIT cmd /c C:/3rdGen/CoreRender/bin/x64/crShadersd.exe cr_gbuffer.es3.vert.glsl
START /WAIT cmd /c C:/3rdGen/CoreRender/bin/x64/crShadersd.exe cr_gbuffer.es3.frag.glsl
START /WAIT cmd /c C:/3rdGen/CoreRender/bin/x64/crShadersd.exe cr_mesh_vbo.es3.vert.glsl
START /WAIT cmd /c C:/3rdGen/CoreRender/bin/x64/crShadersd.exe cr_mesh_vbo.es3.frag.glsl
START /WAIT cmd /c C:/3rdGen/CoreRender/bin/x64/crShadersd.exe cr_environment.es3.vert.glsl
START /WAIT cmd /c C:/3rdGen/CoreRender/bin/x64/crShadersd.exe cr_environment.es3.frag.glsl
START /WAIT cmd /c C:/3rdGen/CoreRender/bin/x64/crShadersd.exe cr_atm_transmittance.es3.frag.glsl
START /WAIT cmd /c C:/3rdGen/CoreRender/bin/x64/crShadersd.exe cr_atm_sky_view.es3.frag.glsl