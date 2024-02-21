pushd %~dp0\preprocessed

copy /y cr_gbuffer.es3.vert.glsl cr_gbuffer.es3.vert
copy /y cr_gbuffer.es3.frag.glsl cr_gbuffer.es3.frag
copy /y cr_mesh_vbo.es3.vert.glsl cr_mesh_vbo.es3.vert
copy /y cr_mesh_vbo.es3.frag.glsl cr_mesh_vbo.es3.frag
copy /y cr_environment.es3.vert.glsl cr_environment.es3.vert
copy /y cr_environment.es3.frag.glsl cr_environment.es3.frag
copy /y cr_atm_transmittance.es3.frag.glsl cr_atm_transmittance.es3.frag
copy /y cr_atm_sky_view.es3.frag.glsl cr_atm_sky_view.es3.frag
C:/VulkanSDK/1.3.239.0/Bin/glslc.exe cr_gbuffer.es3.vert -fshader-stage=vert -o cr_gbuffer.es3.vert.spv
C:/VulkanSDK/1.3.239.0/Bin/glslc.exe cr_gbuffer.es3.frag -fshader-stage=frag -o cr_gbuffer.es3.frag.spv
C:/VulkanSDK/1.3.239.0/Bin/glslc.exe cr_mesh_vbo.es3.vert -fshader-stage=vert -o cr_mesh_vbo.es3.vert.spv
C:/VulkanSDK/1.3.239.0/Bin/glslc.exe cr_mesh_vbo.es3.frag -fshader-stage=frag -o cr_mesh_vbo.es3.frag.spv
C:/VulkanSDK/1.3.239.0/Bin/glslc.exe cr_environment.es3.vert -fshader-stage=vert -o cr_environment.es3.vert.spv
C:/VulkanSDK/1.3.239.0/Bin/glslc.exe cr_environment.es3.frag -fshader-stage=frag -o cr_environment.es3.frag.spv
C:/VulkanSDK/1.3.239.0/Bin/glslc.exe cr_atm_transmittance.es3.frag -fshader-stage=frag -o cr_atm_transmittance.es3.frag.spv
C:/VulkanSDK/1.3.239.0/Bin/glslc.exe cr_atm_sky_view.es3.frag -fshader-stage=frag -o cr_atm_sky_view.es3.frag.spv
DEL cr_gbuffer.es3.vert
DEL cr_gbuffer.es3.frag
DEL cr_mesh_vbo.es3.vert
DEL cr_mesh_vbo.es3.frag
DEL cr_environment.es3.vert
DEL cr_environment.es3.frag
DEL cr_atm_transmittance.es3.frag
DEL cr_atm_sky_view.es3.frag

popd