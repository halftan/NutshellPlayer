//
//  shader.metal
//  MyMTLTestApp
//
//

#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoords;
};

[[vertex]]
VertexOut vertex_main(uint vertexID [[vertex_id]],
                      constant float4x4 &modelProjectionMatrix [[buffer(0)]])
{
    float2 vertices[] = {
        { 0.0f, 0.0f },
        { 0.0f, 1.0f },
        { 1.0f, 0.0f },
        { 1.0f, 1.0f },
    };
    float2 modelPosition = vertices[vertexID];
    float2 texCoords = vertices[vertexID];

    float4 clipPosition = modelProjectionMatrix * float4(modelPosition, 0.0f, 1.0f);

    return {
        clipPosition,
//        float4(modelPosition, 0.0f, 1.0f),
        texCoords,
    };
}

[[vertex]]
VertexOut vertex_fullscreen(uint vid [[vertex_id]]) {
    float2 positions[4] = { {-1,-1}, {1,-1}, {-1,1}, {1,1} };
    float2 uvs[4] = { {0,1}, {1,1}, {0,0}, {1,0} };

    VertexOut out;
    out.position = float4(positions[vid], 0, 1);
    out.texCoords = uvs[vid];
    return out;
}


float2 texture_mapping(float2 texCoords, uint viewID) {
   return float2(texCoords.x * 0.5 + viewID * 0.5, texCoords.y);
    // return texCoords.xy;
}

// Linear Rec.709 to Linear Display P3 conversion matrix
// Derived via CIE XYZ: Rec.709 → XYZ → P3
// Values from ICC/Apple/SMPTE standards
constant half3x3 REC709_TO_P3_MATRIX = half3x3(
                                               half3( 1.2249401h, -0.0420569h, -0.0196376h ),
                                               half3(-0.2249401h,  1.0420569h,  0.0196376h ),
                                               half3( 0.0h,        0.0h,        1.0h )
//                                               half3(1.2249401h, -0.2249401h, 0.0h),
//                                               half3(-0.0420569h, 1.0420569h, 0.0h),
//                                               half3(-0.0196376h, 0.0196376h, 1.0h)
                                               );

half3 tonemap_rec709_to_p3(half3 linear_rec709_rgb, half intensity) {
    // Apply optional intensity scaling (e.g., for exposure adjustment)
    half3 scaled = linear_rec709_rgb * intensity;

    // Convert linear Rec.709 RGB → linear Display P3 RGB
    half3 linear_p3 = REC709_TO_P3_MATRIX * scaled;

    // Optional: clamp to [0, 1] if you're targeting SDR P3 display
    // For HDR, you might omit clamping or use tone mapping instead
    return clamp(linear_p3, 0.0h, 1.0h);
}

float3 tonemap_maxrgb(float3 x, float maxInput, float maxOutput) {
    if (maxInput <= maxOutput) {
        return x;
    }
    float a = maxOutput / (maxInput * maxInput);
    float b = 1.0f / maxOutput;
    float colorMax = max(x.r, max(x.g, x.b));
    return x * (1.0f + a * colorMax) / (1.0f + b * colorMax);
}

[[fragment]]
half4 fragment_linear_sbs(VertexOut in [[stage_in]],
                          texture2d<half> frameTexture [[texture(0)]],
                          constant int &viewID [[buffer(0)]])
{
    constexpr sampler bilinearSampler(address::clamp_to_edge, filter::linear, mip_filter::none);
    half4 color = frameTexture.sample(bilinearSampler, float2(in.texCoords.x * 0.5 + viewID * 0.5, in.texCoords.y));
//    color.rgb = tonemap_rec709_to_p3(color.rgb, 1.0h);
    return color;
}

[[fragment]]
half4 fragment_linear(VertexOut in [[stage_in]],
                      texture2d<half> frameTexture [[texture(0)]])
{
    constexpr sampler bilinearSampler(address::clamp_to_edge, filter::linear, mip_filter::none);
    half4 color = frameTexture.sample(bilinearSampler, in.texCoords);
    return color;
}

// ========== Fragment Shader: YUV → Linear Display P3 ==========

// BT.709 full-range YUV to gamma-encoded RGB matrix
// Assumes Y ∈ [0,1], Cb/Cr ∈ [-0.5, 0.5]
constant half3x3 YUV_TO_RGB_BT709 = half3x3(
                                            half3(1.0h,  1.0h, 1.0h),
                                            half3(0.0h, -0.187324h, 1.855600h),
                                            half3(1.574800h, -0.468124h, 0.0h)
                                            );

// Linear Rec.709 to Linear Display P3 color matrix
constant half3x3 REC709_TO_P3 = half3x3(
                                        half3( 1.2249401h, -0.0420569h, -0.0196376h ),
                                        half3(-0.2249401h,  1.0420569h,  0.0196376h ),
                                        half3( 0.0h,        0.0h,        1.0h )
                                        );


// Inverse EOTF: Rec.709 gamma decoding (to linear)
half rec709_inverse_oetf(half c) {
    if (c <= 0.081h) {
        return c / 4.5h;
    } else {
        return pow((c + 0.099h) / 1.099h, 1.0h / 0.45h);
    }
}

// ---------- Limited Range Helpers ----------
half3 convert_8bit_limited_yuv(half y_norm, half2 cbcr_norm, uint isGammaEncoded) {
    half y_8bit = y_norm * 255.0h;
    half2 cbcr_8bit = cbcr_norm * 255.0h;
    half y_full = (y_8bit - 16.0h) / 219.0h;           // 235-16=219
    half2 cbcr_centered = (cbcr_8bit - 128.0h) / 224.0h; // 240-16=224
    y_full = clamp(y_full, 0.0h, 1.0h);
    cbcr_centered = clamp(cbcr_centered, -0.5h, 0.5h);

    half3 rgb_gamma = YUV_TO_RGB_BT709 * half3(y_full, cbcr_centered.r, cbcr_centered.g);
    if (0 == isGammaEncoded) {
        return tonemap_rec709_to_p3(rgb_gamma, 1.0);
    }
    // reverse gamma encoding to linear space
    half3 linear_rec709 = half3(
        rec709_inverse_oetf(rgb_gamma.r),
        rec709_inverse_oetf(rgb_gamma.g),
        rec709_inverse_oetf(rgb_gamma.b)
    );
    return clamp(tonemap_rec709_to_p3(linear_rec709, 1.0), 0.0h, 1.0h);
}

half3 convert_10bit_limited_yuv(half y_norm, half2 cbcr_norm, uint isGammaEncoded) {
    half y_10bit = y_norm * 1023.0h;
    half2 cbcr_10bit = cbcr_norm * 1023.0h;
    half y_full = (y_10bit - 64.0h) / 876.0h;           // 940-64=876
    half2 cbcr_centered = (cbcr_10bit - 512.0h) / 896.0h; // 960-64=896
    y_full = clamp(y_full, 0.0h, 1.0h);
    cbcr_centered = clamp(cbcr_centered, -0.5h, 0.5h);
    
    half3 rgb_gamma = YUV_TO_RGB_BT709 * half3(y_full, cbcr_centered.r, cbcr_centered.g);
    if (0 == isGammaEncoded) {
        return tonemap_rec709_to_p3(rgb_gamma, 1.0);
    }
    // reverse gamma encoding to linear space
    half3 linear_rec709 = half3(
        rec709_inverse_oetf(rgb_gamma.r),
        rec709_inverse_oetf(rgb_gamma.g),
        rec709_inverse_oetf(rgb_gamma.b)
    );
    return clamp(REC709_TO_P3 * linear_rec709, 0.0h, 1.0h);
}

// ---------- Full Range Helpers ----------
half3 convert_8bit_full_yuv(half y_norm, half2 cbcr_norm, uint isGammaEncoded) {
    // Full range: Y ∈ [0,1], CbCr ∈ [0,1] → center chroma
    half y_full = y_norm;
    half2 cbcr_centered = cbcr_norm - 0.5h;
    y_full = clamp(y_full, 0.0h, 1.0h);
    cbcr_centered = clamp(cbcr_centered, -0.5h, 0.5h);

    half3 rgb_gamma = YUV_TO_RGB_BT709 * half3(y_full, cbcr_centered.r, cbcr_centered.g);
    if (0 == isGammaEncoded) {
        return tonemap_rec709_to_p3(rgb_gamma, 1.0);
    }
    // reverse gamma encoding to linear space
    half3 linear_rec709 = half3(
        rec709_inverse_oetf(rgb_gamma.r),
        rec709_inverse_oetf(rgb_gamma.g),
        rec709_inverse_oetf(rgb_gamma.b)
    );
    return clamp(REC709_TO_P3 * linear_rec709, 0.0h, 1.0h);
}

half3 convert_10bit_full_yuv(half y_norm, half2 cbcr_norm, uint isGammaEncoded) {
    // Same as 8-bit full! Bit depth doesn't matter in full range [0,1]
    return convert_8bit_full_yuv(y_norm, cbcr_norm, isGammaEncoded);
}

// ---------- 8-bit Limited ----------
[[fragment]]
half4 fragment_8bit_limited_sbs(VertexOut in [[stage_in]],
                                constant uint &viewID [[buffer(0)]],
                                constant uint &isGammaEncoded [[buffer(1)]],
                                texture2d<half, access::sample> lumaTexture [[texture(0)]],
                                texture2d<half, access::sample> chromaTexture [[texture(1)]]) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    float2 uv = texture_mapping(in.texCoords, viewID);
    half y = lumaTexture.sample(s, uv).r;
    half2 cbcr = chromaTexture.sample(s, uv).rg;
    return half4(convert_8bit_limited_yuv(y, cbcr, isGammaEncoded), 1.0h);
}

// ---------- 10-bit Limited ----------
[[fragment]]
half4 fragment_10bit_limited_sbs(VertexOut in [[stage_in]],
                                 constant uint &viewID [[buffer(0)]],
                                 constant uint &isGammaEncoded [[buffer(1)]],
                                 texture2d<half, access::sample> lumaTexture [[texture(0)]],
                                 texture2d<half, access::sample> chromaTexture [[texture(1)]]) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    float2 uv = texture_mapping(in.texCoords, viewID);
    half y = lumaTexture.sample(s, uv).r;
    half2 cbcr = chromaTexture.sample(s, uv).rg;
    return half4(convert_10bit_limited_yuv(y, cbcr, isGammaEncoded), 1.0h);
}

// ---------- 8-bit Full ----------
[[fragment]]
half4 fragment_8bit_full_sbs(VertexOut in [[stage_in]],
                             constant uint &viewID [[buffer(0)]],
                             constant uint &isGammaEncoded [[buffer(1)]],
                             texture2d<half, access::sample> lumaTexture [[texture(0)]],
                             texture2d<half, access::sample> chromaTexture [[texture(1)]]) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    float2 uv = texture_mapping(in.texCoords, viewID);
    half y = lumaTexture.sample(s, uv).r;
    half2 cbcr = chromaTexture.sample(s, uv).rg;
    return half4(convert_8bit_full_yuv(y, cbcr, isGammaEncoded), 1.0h);
}

// ---------- 10-bit Full ----------
[[fragment]]
half4 fragment_10bit_full_sbs(VertexOut in [[stage_in]],
                              constant uint &viewID [[buffer(0)]],
                              constant uint &isGammaEncoded [[buffer(1)]],
                              texture2d<half, access::sample> lumaTexture [[texture(0)]],
                              texture2d<half, access::sample> chromaTexture [[texture(1)]]) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    float2 uv = texture_mapping(in.texCoords, viewID);
    half y = lumaTexture.sample(s, uv).r;
    half2 cbcr = chromaTexture.sample(s, uv).rg;
    return half4(convert_10bit_full_yuv(y, cbcr, isGammaEncoded), 1.0h);
}
