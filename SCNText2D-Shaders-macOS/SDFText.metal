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
    float2 uv [[ attribute(SCNVertexSemanticTexcoord0) ]];
} input_t;

typedef struct {
    float4x4 modelViewProjectionTransform;
} node_t;

typedef struct {
    float4 position [[ position ]];
    float2 uv;
} io_t;

vertex io_t sdfTextVertex(input_t in [[ stage_in ]],
                               constant SCNSceneBuffer& scn_frame [[ buffer(0) ]],
                               constant node_t& scn_node [[ buffer(1) ]]) {
    io_t out;
    out.position = scn_node.modelViewProjectionTransform * in.position;
    out.uv = in.uv;
    return out;
}

fragment half4 sdfTextFragment(io_t in [[ stage_in ]],
                               texture2d<float> fontTexture [[ texture(0) ]]) {
    constexpr sampler s(filter::linear);
    float4 sdfColor = fontTexture.sample(s, in.uv);

    float mask = sdfColor.r;
    float delta = 0.1;
    float finalAlpha = smoothstep(0.5 - delta, 0.5 + delta, mask);

    float4 color = float4(1.0 * finalAlpha, 1.0 * finalAlpha, 1.0 * finalAlpha, finalAlpha);

    return half4(color);
}
