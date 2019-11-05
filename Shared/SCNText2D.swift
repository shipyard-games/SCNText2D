//
//  SCNText2D.swift
//  SCNText2D
//
//  Created by Teemu Harju on 10/02/2019.
//

import Foundation
import SceneKit
import Metal
import MetalKit

public class SCNText2D {
    
    public struct SDFParams {
        let smoothing: Float
        let fontWidth: Float
        let outlineWidth: Float
        let shadowWidth: Float
        let shadowOffset: SCNVector4
        let fontColor: Color
        let outlineColor: Color
        let shadowColor: Color
        
        public init(smoothing: Float, fontWidth: Float, outlineWidth: Float, shadowWidth: Float, shadowOffset: SCNVector4, fontColor: Color, outlineColor: Color, shadowColor: Color) {
            self.smoothing = smoothing
            self.fontWidth = fontWidth
            self.outlineWidth = outlineWidth
            self.shadowWidth = shadowWidth
            self.shadowOffset = shadowOffset
            self.fontColor = fontColor
            self.outlineColor = outlineColor
            self.shadowColor = shadowColor
        }
    }
    
    private struct Vertex {
        var x, y, z: Float
        var u, v: Float
    }
    
    #if os(iOS)
    public typealias Color = UIColor
    #else
    public typealias Color = NSColor
    #endif
    
    public enum TextAlignment {
        case left
        case right
        case centered
    }
    
    private static var metricsCache       = [String: FontMetrics]()
    private static var materialCache      = [String: SCNMaterial]()
    
    public static func load(font fontName: String, bundle: Bundle, fontConfig: SDFParams) {
        SCNText2D.loadFontMetrics(for: fontName, bundle: bundle)
    
        let bundle = Bundle(for: SCNText2D.self)
        
        let textureURL = bundle.url(forResource: "crocodile_feet_sdf", withExtension: "png")!
        let textureMaterialProperty = SCNMaterialProperty(contents: textureURL)
        
        let material = SCNMaterial()
        material.name = "SDFText2D::\(fontName)"
        material.lightingModel = .constant
        material.setValue(textureMaterialProperty, forKey: "fontTexture")
        material.setValue(NSNumber(value: fontConfig.smoothing), forKey: "smoothing")
        material.setValue(NSNumber(value: fontConfig.fontWidth), forKey: "fontWidth")
        material.setValue(fontConfig.outlineColor, forKey: "outlineColor")
        material.setValue(fontConfig.fontColor, forKey: "fontColor")
        material.setValue(NSNumber(value: fontConfig.outlineWidth), forKey: "outlineWidth")
        material.setValue(fontConfig.shadowOffset, forKey: "shadowOffset")
        material.setValue(NSNumber(value: fontConfig.shadowWidth), forKey: "shadowWidth")
        material.setValue(fontConfig.shadowColor, forKey: "shadowColor")
        
        material.shaderModifiers = [
            .surface:
            """
            #pragma arguments
            float smoothing;
            float fontWidth;
            float4 outlineColor;
            float4 fontColor;
            float outlineWidth;
            float4 shadowOffset;
            texture2d fontTexture;
            float shadowWidth;
            float4 shadowColor;

            #pragma transparent
            #pragma body
            constexpr sampler s(coord::normalized, address::clamp_to_zero, filter::linear);

            float4 distanceVec       = fontTexture.sample(s, _surface.diffuseTexcoord);
            float distance           = length(distanceVec.rgb);
            float outlineFactor      = smoothstep(fontWidth - smoothing, fontWidth + smoothing, distance);
            float4 color             = mix(outlineColor, fontColor, outlineFactor);
            float alpha              = smoothstep(outlineWidth - smoothing, outlineWidth + smoothing, distance);
            float4 colorWithOutline  = float4(color.rgb * alpha, color.a * alpha);
            float4 shadowDistanceVec = fontTexture.sample(s, _surface.diffuseTexcoord - shadowOffset.xy);
            float shadowDistance     = length(shadowDistanceVec.rgb);
            float shadowAlpha        = smoothstep(shadowWidth - smoothing, shadowWidth + smoothing, shadowDistance);
            float4 shadow            = float4(shadowColor.rgb * shadowAlpha, shadowColor.a * shadowAlpha);
            float4 finalColor        = mix(shadow, colorWithOutline, smoothstep(0.8, 1.0, colorWithOutline.a));

            _surface.diffuse = finalColor;
            """
        ]
        
        
        SCNText2D.materialCache[fontName] = material
    }

    public static func create(from string: String, withFontNamed fontName: String, scale: Float = 1.0, lineSpacing: Float = 1.0, alignment: TextAlignment = .centered) -> SCNGeometry {
        guard let fontMetrics = SCNText2D.metricsCache[fontName] else {
            fatalError("Font '\(fontName)' not loaded. No font metrics found.")
        }

        let geometry = buildGeometry(string, fontMetrics, alignment, scale, lineSpacing)
        if let material = SCNText2D.materialCache[fontName] {
            geometry.materials = [material]
        }
        return geometry
    }
    
    public static func clone(fontNamed fontName: String, toFontNamed newFontName: String, using fontConfig: SDFParams) {
        guard let metrics = metricsCache[fontName], let material = materialCache[fontName] else {
            fatalError("Trying to clone a font that does not exist. fontName=\(fontName)")
        }
        
        // Use same materiala and metrics for new font
        metricsCache[newFontName] = metrics
        
        // Create new material using the new font config.
        guard let newMaterial = material.copy() as? SCNMaterial else {
            fatalError("Failed to copy material.")
        }
        
        materialCache[newFontName] = newMaterial
    }

    private static func buildGeometry(_ string: String, _ fontMetrics: FontMetrics, _ alignment: TextAlignment, _ scale: Float, _ lineSpacing: Float) -> SCNGeometry {
    
        let lines = string.unicodeScalars.split(separator: Unicode.Scalar("\n"))
        
        let textureWidth = fontMetrics.naturalWidth
        let textureHeight = fontMetrics.naturalHeight
        
        var cursorX: Float = 0.0
        var cursorY: Float = 0.0

        var vertices = [Vertex]()
        
        var lineVertices = [Vertex]()

        var indices = [UInt16]()

        var minX: Float = Float.infinity
        var minY: Float = Float.infinity
        var maxX: Float = -Float.infinity
        var maxY: Float = -Float.infinity
        
        for line in lines {
            var lineMaxYOffset: Float = -Float.infinity
            for (i, char) in line.enumerated() {
                guard let glyph = fontMetrics.glyphMap[char] else {
                    cursorX += fontMetrics.glyphMap[Unicode.Scalar(0x0020)]!.advanceX
                    continue
                }

                let glyphWidth    = glyph.width * scale;
                let glyphHeight   = glyph.height * scale;
                let glyphBearingX = glyph.bearingX * scale;
                let glyphBearingY = glyph.bearingY * scale;
                let glyphAdvanceX = glyph.advanceX * scale;
                let glyphAdvanceY = glyph.advanceY * scale;

                let x = cursorX + glyphBearingX;
                let y = cursorY + glyphBearingY;
                let z = Float(i) * 0.1

                let lineYOffset = glyphBearingY - glyphHeight

                if lineYOffset < 0.0 { // below baseline
                    if lineYOffset < lineMaxYOffset {
                        lineMaxYOffset = lineYOffset
                    }
                }

                if y > maxY { maxY = y}
                if x < minX { minX = x }

                if (y - glyphHeight) < minY { minY = y - glyphHeight }
                if (x + glyphWidth) > maxX { maxX = x + glyphWidth }

                let w = glyph.width / textureWidth
                let h = glyph.height / textureHeight
                let s0 = glyph.x / textureWidth
                let t0 = glyph.y / textureHeight
                let s1 = s0 + w
                let t1 = t0 + h

                let v1 = Vertex(x: x, y: y - glyphHeight, z: z, u: s0, v: t1)
                let v2 = Vertex(x: x + glyphWidth, y: y - glyphHeight, z: z, u: s1, v: t1)
                let v3 = Vertex(x: x, y: y, z: z, u: s0, v: t0)
                let v4 = Vertex(x: x + glyphWidth, y: y, z: z, u: s1, v: t0)

                lineVertices.append(v1)
                lineVertices.append(v2)
                lineVertices.append(v3)
                lineVertices.append(v4)

                let curidx = UInt16(vertices.count + i * 4)
                indices.append(curidx + 0)
                indices.append(curidx + 1)
                indices.append(curidx + 2) // first triangle
                indices.append(curidx + 1)
                indices.append(curidx + 3)
                indices.append(curidx + 2) // second triangle

                cursorX += glyphAdvanceX
            }

            cursorY -= fontMetrics.maxDescent + fontMetrics.fontHeight * scale * lineSpacing

            alignLine(&lineVertices, withAlignment: alignment, lineWidth: cursorX)

            vertices.append(contentsOf: lineVertices)

            cursorX = 0
            lineVertices = []
        }

        // Center align the vertices vertically
        let width = maxX - minX
        vertices = vertices.map {
            (vertex: Vertex) in
            var vertex = vertex
            switch (alignment) {
            case .centered:
            break // already aligned per line
            case .left:
                vertex.x -= width / 2
            case .right:
                vertex.x += width / 2
            }
            return vertex
        }
        
        let indicesData = Data(bytes: &indices, count: MemoryLayout<UInt16>.size * indices.count)
        let element = SCNGeometryElement(data: indicesData, primitiveType: .triangles, primitiveCount: indices.count / 3, bytesPerIndex: MemoryLayout<UInt16>.size)
        
        let verticesData = Data(bytes: &vertices, count: MemoryLayout<Vertex>.size * vertices.count)
        
        let vertexSource = SCNGeometrySource(data: verticesData, semantic: .vertex, vectorCount: vertices.count,
                                             usesFloatComponents: true, componentsPerVector: 3,
                                             bytesPerComponent: MemoryLayout<Float>.size, dataOffset: 0,
                                             dataStride: MemoryLayout<Vertex>.size)
        
        let uvSource = SCNGeometrySource(data: verticesData, semantic: .texcoord, vectorCount: vertices.count,
                                         usesFloatComponents: true, componentsPerVector: 2,
                                         bytesPerComponent: MemoryLayout<Float>.size,
                                         dataOffset: MemoryLayout<Float>.size * 3,
                                         dataStride: MemoryLayout<Vertex>.size)

        let geometry = SCNGeometry(sources: [vertexSource, uvSource], elements: [element])

        return geometry
    }
    
    private static func alignLine(_ lineVertices: inout [Vertex], withAlignment alignment: TextAlignment, lineWidth: Float) {
        switch (alignment) {
        case .centered:
            lineVertices = lineVertices.map {
                (vertex: Vertex) -> Vertex in
                var vertex = vertex
                vertex.x -= lineWidth / 2
                return vertex
            }
        case .left:
            // we keep the lines first glyph starting at zero and center the geometry once it is complete
            break
        case .right:
            // we move the last glyphs position to zero so we can do right alignment once the geometry is complete
            lineVertices = lineVertices.map {
                (vertex: Vertex) -> Vertex in
                var vertex = vertex
                vertex.x -= lineWidth
                return vertex
            }
        }
    }
    
    private static func loadFontMetrics(for fontNamed: String, bundle: Bundle) {
        let jsonURL = bundle.url(forResource: fontNamed, withExtension: "fnt")!
        let jsonData = try! Data(contentsOf: jsonURL)
        
        let metrics = try! JSONDecoder().decode(FontMetrics.self, from: jsonData)
        
        // Populate glyph map
        for glyph in metrics.glyphs {
            if let charCode = Unicode.Scalar(glyph.charCode) {
                metrics.glyphMap[Unicode.Scalar(charCode)] = glyph
                
                let ascent = glyph.bearingY
                let descent = glyph.height - glyph.bearingY
                
                if ascent > metrics.maxAscent {
                    metrics.maxAscent = ascent
                }
                
                if descent > metrics.maxDescent {
                    metrics.maxDescent = descent
                }
            }
        }
        
        SCNText2D.metricsCache[fontNamed] = metrics
    }
}

