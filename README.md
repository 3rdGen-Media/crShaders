## crShaders

crShaders is a project meant to be included directly in a Visual Studio solution or Xcode workspace to preprocess, compile then copy final output to a desired install location when you initiate build/run.  It demonstrates how to maintain congruent shader source across GLSL, HLSL, SPIR-V and Metal Shaders using definitions in shared header includes. 

#### Preprocessing

crShaders/main.c generates a cmd line application that accepts paths to (.glsl) shader source files as cmd line args. Each source file is loaded from disk and parsed for include header statements while each header is then recursively searched to concatenate their contents to a single output source file dumped to a /preprocessed dir. If no headers are present in the source file a copy of the file will be placed in the /preprocessed dir. 

Only .glsl shaders require preprocessing because .hlsl and .metal shaders provide native support for header includes without explicitly enabling via an extension.

#### Compilation

Preprocessed .glsl files are compiled to .spv, .hlsl files are compiled to .cso, and .metal files are compiled to a shared .metallib in place.

#### Packaging

After preprocessing and compilation, the outputs of those stages are copied to the output location specified via post-build scripts (eg /include/CoreRender/crShaders).
