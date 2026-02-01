//
//  Halftone.metal
//  Halftone
//
//  CMYK halftone effect shader with newspaper-style dot patterns
//

#include <metal_stdlib>
#include "ShaderTypes.h"

using namespace metal;

// CMYK halftone angles (in radians) for authentic newspaper look
// These angles minimize moiré patterns
constant float kCyanAngle = 0.261799;    // 15 degrees
constant float kMagentaAngle = 1.309;    // 75 degrees
constant float kYellowAngle = 0.0;       // 0 degrees
constant float kBlackAngle = 0.785398;   // 45 degrees

// Vertex shader output
struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// Fullscreen quad vertex shader
vertex VertexOut vertexShader(uint vertexID [[vertex_id]],
                               constant Vertex *vertices [[buffer(VertexInputIndexVertices)]]) {
    VertexOut out;
    out.position = float4(vertices[vertexID].position, 0.0, 1.0);
    out.texCoord = vertices[vertexID].texCoord;
    return out;
}

// Convert RGB to CMYK
float4 rgbToCmyk(float3 rgb) {
    float k = 1.0 - max(max(rgb.r, rgb.g), rgb.b);

    // Avoid division by zero
    if (k >= 1.0) {
        return float4(0.0, 0.0, 0.0, 1.0);
    }

    float invK = 1.0 / (1.0 - k);
    float c = (1.0 - rgb.r - k) * invK;
    float m = (1.0 - rgb.g - k) * invK;
    float y = (1.0 - rgb.b - k) * invK;

    return float4(c, m, y, k);
}

// Convert CMYK to RGB
float3 cmykToRgb(float4 cmyk) {
    float invK = 1.0 - cmyk.w;
    float r = (1.0 - cmyk.x) * invK;
    float g = (1.0 - cmyk.y) * invK;
    float b = (1.0 - cmyk.z) * invK;
    return float3(r, g, b);
}

// Rotate a 2D point around origin
float2 rotatePoint(float2 p, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return float2(p.x * c - p.y * s, p.x * s + p.y * c);
}

// Highlight threshold - no dots below this density (authentic Dmin behavior)
constant float kHighlightThreshold = 0.08;

// Calculate halftone dot intensity for a single channel
// Returns 1.0 if pixel is inside dot, 0.0 if outside
float halftoneChannel(float2 pixelPos, float channelValue, float dotSize, float angle) {
    // No dots in highlights (authentic Dmin behavior - "white paper" showing)
    if (channelValue < kHighlightThreshold) {
        return 0.0;
    }

    // Remap remaining range for smoother transition from threshold
    float adjusted = (channelValue - kHighlightThreshold) / (1.0 - kHighlightThreshold);

    // Rotate coordinate system for this channel's angle
    float2 rotatedPos = rotatePoint(pixelPos, angle);

    // Find center of nearest dot cell
    float2 cellPos = floor(rotatedPos / dotSize + 0.5) * dotSize;

    // Distance from pixel to dot center
    float2 delta = rotatedPos - cellPos;
    float dist = length(delta);

    // Dot radius based on adjusted channel value (more ink = larger dot)
    // sqrt gives perceptually linear scaling
    float maxRadius = dotSize * 0.5;
    float dotRadius = maxRadius * sqrt(adjusted);

    // Anti-aliased edge - solid dot (1.0 inside, 0.0 outside)
    float edge = smoothstep(dotRadius + 0.5, dotRadius - 0.5, dist);

    // Letterpress halo effect: dark ring with lighter center
    // This mimics ink being pushed outward under pressure
    float centerDist = dist / max(dotRadius, 0.001);  // Avoid division by zero
    float halo = smoothstep(0.3, 0.9, centerDist) * 0.25;

    return edge * (1.0 + halo);  // Slightly darker at edges
}

// Fragment shader - applies CMYK halftone effect
fragment float4 fragmentShader(VertexOut in [[stage_in]],
                                texture2d<float> screenTexture [[texture(TextureIndexScreen)]],
                                constant HalftoneUniforms &uniforms [[buffer(0)]]) {
    // Sample the screen texture
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    float4 screenColor = screenTexture.sample(textureSampler, in.texCoord);

    // If intensity is 0, return original
    if (uniforms.intensity <= 0.0) {
        return screenColor;
    }

    // Get pixel position in screen coordinates
    float2 pixelPos = in.texCoord * uniforms.screenSize;

    float3 halftoneRgb;

    if (uniforms.useBlackOnly != 0) {
        // Black-only mode: newspaper-style using only K channel
        // Convert to grayscale using luminance weights
        float gray = dot(screenColor.rgb, float3(0.299, 0.587, 0.114));
        float k = 1.0 - gray;  // Darkness value

        float kHalftone = halftoneChannel(pixelPos, k, uniforms.dotSize, kBlackAngle);

        // White paper minus black dots
        halftoneRgb = float3(1.0 - kHalftone);
    } else {
        // Full CMYK mode
        // Convert to CMYK
        float4 cmyk = rgbToCmyk(screenColor.rgb);

        // Apply halftone pattern to each CMYK channel with different angles
        float c = halftoneChannel(pixelPos, cmyk.x, uniforms.dotSize, kCyanAngle);
        float m = halftoneChannel(pixelPos, cmyk.y, uniforms.dotSize, kMagentaAngle);
        float y = halftoneChannel(pixelPos, cmyk.z, uniforms.dotSize, kYellowAngle);
        float k = halftoneChannel(pixelPos, cmyk.w, uniforms.dotSize, kBlackAngle);

        // Convert halftoned CMYK back to RGB
        halftoneRgb = cmykToRgb(float4(c, m, y, k));
    }

    // Blend with original based on intensity
    float3 finalRgb = mix(screenColor.rgb, halftoneRgb, uniforms.intensity);

    return float4(finalRgb, screenColor.a);
}
