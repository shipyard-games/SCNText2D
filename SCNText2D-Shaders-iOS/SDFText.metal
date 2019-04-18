//
//  SDFText.metal
//  SCNText2D
//
//  Created by Teemu Harju on 10/02/2019.
//

#include <metal_stdlib>
using namespace metal;

#include <SceneKit/scn_metal>

typedef struct {
    float4 position [[ attribute(SCNVertexSemanticPosition) ]];
    float2 uv       [[ attribute(SCNVertexSemanticTexcoord0) ]];
} input_t;

typedef struct {
    float4x4 modelViewProjectionTransform;
} node_t;

typedef struct {
    float4 position [[ position ]];
    float2 uv;
} io_t;

typedef struct {
    float smoothing;
    float fontWidth;
    float outlineWidth;
    float shadowWidth;
    float2 shadowOffset;
    float4 fontColor;
    float4 outlineColor;
    float4 shadowColor;
} params_t;

vertex io_t sdfTextVertex(input_t in [[ stage_in ]],
                          constant SCNSceneBuffer& scn_frame [[ buffer(0) ]],
                          constant node_t& scn_node [[ buffer(1) ]]) {
    io_t out;
    out.position = scn_node.modelViewProjectionTransform * in.position;
    out.uv       = in.uv;
    
    return out;
}

constexpr sampler s(coord::normalized, address::clamp_to_zero, filter::linear);

fragment half4 sdfTextFragment(io_t in [[ stage_in ]],
                               texture2d<float> fontTexture [[ texture(0) ]],
                               constant params_t& params [[ buffer(1) ]]) {
    
    float4 distanceVec = fontTexture.sample(s, in.uv);
    float distance     = length(distanceVec.rgb);
    float finalColor   = smoothstep(params.fontWidth - params.smoothing, params.fontWidth + params.smoothing, distance);
    
    return half4(finalColor);
}

fragment half4 sdfTextOutlineFragment(io_t in [[ stage_in ]],
                                      texture2d<float> fontTexture [[ texture(0) ]],
                                      constant params_t& params [[ buffer(1) ]]) {
    
    float4 distanceVec  = fontTexture.sample(s, in.uv);
    float distance      = length(distanceVec.rgb);
    float outlineFactor = smoothstep(params.fontWidth - params.smoothing, params.fontWidth + params.smoothing, distance);
    float4 color        = mix(params.outlineColor, params.fontColor, outlineFactor);
    float alpha         = smoothstep(params.outlineWidth - params.smoothing, params.outlineWidth + params.smoothing, distance);
    float4 finalColor   = float4(color.rgb * alpha, color.a * alpha);
    
    return half4(finalColor);
}

fragment half4 sdfTextOutlineShadowFragment(io_t in [[ stage_in ]],
                                            texture2d<float> fontTexture [[ texture(0) ]],
                                            constant params_t& params [[ buffer(1) ]]) {
    
    float4 distanceVec       = fontTexture.sample(s, in.uv);
    float distance           = length(distanceVec.rgb);
    float outlineFactor      = smoothstep(params.fontWidth - params.smoothing, params.fontWidth + params.smoothing, distance);
    float4 color             = mix(params.outlineColor, params.fontColor, outlineFactor);
    float alpha              = smoothstep(params.outlineWidth - params.smoothing, params.outlineWidth + params.smoothing, distance);
    float4 colorWithOutline  = float4(color.rgb * alpha, color.a * alpha);
    float4 shadowDistanceVec = fontTexture.sample(s, in.uv - params.shadowOffset);
    float shadowDistance     = length(shadowDistanceVec.rgb);
    float shadowAlpha        = smoothstep(params.shadowWidth - params.smoothing, params.shadowWidth + params.smoothing, shadowDistance);
    float4 shadow            = float4(params.shadowColor.rgb * shadowAlpha, params.shadowColor.a * shadowAlpha);
    float4 finalColor        = mix(shadow, colorWithOutline, smoothstep(0.8, 1.0, colorWithOutline.a));
    
    return half4(finalColor);
}
