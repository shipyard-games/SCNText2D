//
//  SDFText.metal
//  SCNText2D
//
//  Created by Teemu Harju on 10/02/2019.
//

#import <metal_stdlib>

using namespace metal;

#import <SceneKit/scn_metal>

struct VertexIn {
    float3 position         [[attribute(SCNVertexSemanticPosition)]];
    float2 texcoord         [[attribute(SCNVertexSemanticTexcoord0)]];
};

struct VertexOutput {
    float4 position [[position]];
    float4 color;
    float2 texCoord;
};

struct Uniforms {
    float4x4 modelViewProjectionTransform;
};

float3 hsb2rgb(float3 c) {
    float3 rgb = clamp(abs(fmod(c.x * 6.0 + float3(0.0, 4.0, 2.0), 6.0) -3.0 ) - 1.0,
                       0.0,
                       1.0);
    rgb = rgb * rgb * (3.0 - 2.0 * rgb);
    return c.z * mix(float3(1.0), rgb, c.y);
}


constexpr sampler s = sampler(coord::normalized, address::clamp_to_zero, filter::linear);

// Vertex shader
vertex VertexOutput distanceShadowVertex(VertexIn vertexIn [[stage_in]],
                                         constant Uniforms& scn_node [[buffer(1)]])
{
    VertexOutput vertexOut;
    vertexOut.position = scn_node.modelViewProjectionTransform * float4(vertexIn.position, 1);;
    vertexOut.texCoord = vertexIn.texcoord;
    vertexOut.color = float4(1.0);
    return vertexOut;
}

// Fragment shader
fragment float4 distanceShadowFrag(VertexOutput fragmentIn [[stage_in]],
                                   texture2d<float> diffuseTexture [[texture(0)]],                                   
                                   device float *smoothing [[ buffer(1) ]],
                                   device float4 *textColor  [[ buffer(2) ]],
                                   device float4 *borderColor  [[ buffer(3) ]]
                                   )
{
    // The bigger the number, the smaller the size
    const float textWidth = 0.9;
    const float outlineWidth = 0.5;
    const float shadowWidth = 0.5;
    
    const float2 shadowOffset = float2(0.00, 0.001);
    
    float iSmoothing = *smoothing;
    float4 iTextColor = *textColor;
    const float4 outlineColor = *borderColor;
    const float4 shadowColor = outlineColor;
    
    float4 distanceVec = diffuseTexture.sample(s, fragmentIn.texCoord);
    float distance = length(distanceVec.rgb);
    float outlineFactor = smoothstep(textWidth - iSmoothing, textWidth + iSmoothing, distance);
    float4 color = mix(outlineColor, iTextColor, outlineFactor);
    
    float alpha = smoothstep(outlineWidth - iSmoothing, outlineWidth + iSmoothing, distance);
    float4 colorWithOutline = float4(color.rgb * alpha, color.a * alpha);
    
    float4 shadowDistanceVec = diffuseTexture.sample(s, fragmentIn.texCoord - shadowOffset);
    float shadowDistance = length(shadowDistanceVec.rgb);
    float shadowAlpha = smoothstep(shadowWidth - iSmoothing, shadowWidth + iSmoothing, shadowDistance);
    float4 shadow = float4(shadowColor.rgb * shadowAlpha, shadowColor.a * shadowAlpha);
    return mix(shadow, colorWithOutline, smoothstep(0.8, 1.0, colorWithOutline.a));
}
