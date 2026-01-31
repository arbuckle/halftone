//
//  ShaderTypes.h
//  Halftone
//
//  Shared types between Metal shaders and Swift code
//

#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

// Vertex input/output indices
typedef enum VertexInputIndex {
    VertexInputIndexVertices = 0,
    VertexInputIndexUniforms = 1
} VertexInputIndex;

// Fragment texture indices
typedef enum TextureIndex {
    TextureIndexScreen = 0
} TextureIndex;

// Vertex data for fullscreen quad
typedef struct {
    vector_float2 position;
    vector_float2 texCoord;
} Vertex;

// Uniforms passed to fragment shader
typedef struct {
    float dotSize;          // Size of halftone dots in pixels
    float intensity;        // Effect intensity (0.0 = off, 1.0 = full)
    vector_float2 screenSize;  // Screen dimensions in pixels
} HalftoneUniforms;

#endif /* ShaderTypes_h */
