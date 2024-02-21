#use mkdir -p option to create install dirs if they don't exist
mkdir -p ../../../include/CoreRender/crShaders
mkdir -p ../../../include/CoreRender/crShaders/glsl
mkdir -p ../../../include/CoreRender/crShaders/hlsl
mkdir -p ../../../include/CoreRender/crShaders/metal

#run glsl preprocessing application for each glsl source file 
#mkdir -p ../include/CoreRender/crShaders/glsl/preprocessed;
#$TARGET_BUILD_DIR/./crShaders-GLSL ./crShaders/glsl/cr_gbuffer.es2.vert.glsl
#$TARGET_BUILD_DIR/./crShaders-GLSL ./crShaders/glsl/cr_gbuffer.es2.frag.glsl
#$TARGET_BUILD_DIR/./crShaders-GLSL ./crShaders/glsl/cr_mesh_vbo.es2.vert.glsl
#$TARGET_BUILD_DIR/./crShaders-GLSL ./crShaders/glsl/cr_mesh_vbo.es2.frag.glsl
#$TARGET_BUILD_DIR/./crShaders-GLSL ./crShaders/glsl/cr_environment.es2.vert.glsl
#$TARGET_BUILD_DIR/./crShaders-GLSL ./crShaders/glsl/cr_environment.es2.frag.glsl
#$TARGET_BUILD_DIR/./crShaders-GLSL ./crShaders/glsl/cr_atm_transmittance.es2.frag.glsl
#$TARGET_BUILD_DIR/./crShaders-GLSL ./crShaders/glsl/cr_atm_scattering.es2.frag.glsl
#$TARGET_BUILD_DIR/./crShaders-GLSL ./crShaders/glsl/cr_atm_sky_view.es2.frag.glsl

#cp -rvf ./crShaders/crgc_vbo.h ../include/CoreRender/crShaders/
#cp -rvf ./crShaders/MtlShaderInterface.h ../include/CoreRender/crShaders/
#cp -rvf ./crShaders/cr_sky_atmosphere.h ../include/CoreRender/crShaders/
cp -rvf ../cr_atm_params.glsl ../../../include/CoreRender/crShaders/
cp -rvf ../cr_atm_functions.glsl ../../../include/CoreRender/crShaders/
cp -rvf ./preprocessed/ ../../../include/CoreRender/crShaders/glsl/
cp -rvf ../metal/ ../../../include/CoreRender/crShaders/metal
cp -rvf ../*.h ../../../include/CoreRender/crShaders/

#find ./crUtils '.h' -exec cp -vuni '{}' "../include/CoreRender/crUtils" ";"
cp -rvf ../../crShader.h ../../../include/CoreRender/

#cp -rvf $TARGET_BUILD_DIR/crShaders-OSX.metallib ./crShaders/metal/
