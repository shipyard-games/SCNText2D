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
    
    private struct SDFParams {
        let smoothing: Float
        let fontWidth: Float
        let outlineWidth: Float
        let shadowWidth: Float
        let shadowOffset: float2
        let fontColor: float4
        let outlineColor: float4
        let shadowColor: float4
    }
    
    private struct Vertex {
        var x, y, z: Float
        var u, v: Float
    }
    
    public typealias Color = float4
    
    typealias AtlasData = Dictionary<String, Any>
    
    public enum TextAlignment {
        case left
        case right
        case centered
    }
    
    private static var textureCache = [String : MTLTexture]()
    private static var metricsCache = [String : FontMetrics]()
    private static var atlasCache   = [String : AtlasData]()
    private static let device = MTLCreateSystemDefaultDevice()!
    
    public static func load(font fontName: String, bundle: Bundle) {
        SCNText2D.loadFontMetrics(for: fontName, bundle: bundle)
        SCNText2D.loadTexture(for: fontName, bundle: bundle)
        SCNText2D.loadAtlasData(for: fontName, bundle: bundle)
    }

    public static func create(from string: String,
                              withFontNamed fontName: String,
                              fontColor: Color = float4(1.0, 1.0, 1.0, 1.0),
                              outlineColor: Color = float4(0.0, 0.0, 0.0, 0.0),
                              shadowColor: Color = float4(0.0, 0.0, 0.0, 0.0),
                              smoothing: Float = 0.04,
                              scale: Float = 1.0,
                              lineSpacing: Float = 1.0,
                              alignment: TextAlignment = .centered,
                              fontWidth: Float = 0.9,
                              outlineWidth: Float = 0.5,
                              shadowWidth: Float = 0.5,
                              shadowOffset: float2 = float2(0.0, 0.0)) -> SCNGeometry {
        
        guard let fontMetrics = SCNText2D.metricsCache[fontName] else {
            fatalError("Font '\(fontName)' not loaded. No font metrics found.")
        }
        
        guard let atlasData = SCNText2D.atlasCache[fontName] else {
            fatalError("Font '\(fontName)' not loaded. No atlas data found.")
        }

        let shaderLibraryUrl = Bundle(for: SCNText2D.self).url(forResource: "SCNText2D-Shaders", withExtension: "metallib")!

        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError( "Failed to get the system's default Metal device." )
        }

        let shaderLibrary = try! device.makeLibrary(URL: shaderLibraryUrl)

        let shaderProgram = SCNProgram()
        shaderProgram.vertexFunctionName = "sdfTextVertex"
        
        switch (outlineColor[3], shadowColor[3]) {
            case (_, let shadow) where shadow > 0.0:
                shaderProgram.fragmentFunctionName = "sdfTextOutlineShadowFragment"

            case (let outline, _) where outline > 0.0:
                shaderProgram.fragmentFunctionName = "sdfTextOutlineFragment"

            default:
                shaderProgram.fragmentFunctionName = "sdfTextFragment"
        }

        shaderProgram.isOpaque = false
        shaderProgram.library = shaderLibrary

        let geometry = buildGeometry(string, fontMetrics, atlasData, alignment, scale, lineSpacing)
        geometry.materials.first?.program = shaderProgram
        
        var params = SDFParams(smoothing: smoothing,
                               fontWidth: fontWidth,
                               outlineWidth: outlineWidth,
                               shadowWidth: shadowWidth,
                               shadowOffset: shadowOffset,
                               fontColor: fontColor,
                               outlineColor: outlineColor,
                               shadowColor: shadowColor)
        
        guard let texture = textureCache[fontName] else {
            fatalError("Font '\(fontName)' not loaded. No texture found.")
        }
        
        geometry.materials.first?.setValue(SCNMaterialProperty(contents: texture), forKey: "fontTexture")
        geometry.materials.first?.setValue(Data(bytes: &params, count: MemoryLayout<SDFParams>.size), forKey: "params")
        
        return geometry
    }

    private static func buildGeometry(_ string: String, _ fontMetrics: FontMetrics, _ atlasData: AtlasData, _ alignment: TextAlignment, _ scale: Float, _ lineSpacing: Float) -> SCNGeometry {
        
        let atlasMeta = atlasData["meta"] as! Dictionary<String, Any>
        
        let textureWidth = (atlasMeta["width"] as! NSNumber).floatValue
        let textureHeight = (atlasMeta["height"] as! NSNumber).floatValue

        var cursorX: Float = 0.0
        var cursorY: Float = 0.0

        var vertices = [Vertex]()
        vertices.reserveCapacity(string.count * 4) // 4 vertices per character
        
        var lineVertices = [Vertex]()

        var indices = [UInt16]()
        indices.reserveCapacity(string.count * 6) // 6 indices per character

        var minX: Float = Float.infinity
        var minY: Float = Float.infinity
        var maxX: Float = -Float.infinity
        var maxY: Float = -Float.infinity

        // We keep track of the number of newlines, since they don't generate any
        // vertices like all other glyphs do. We use this count to adjust the indices
        // of the test geometry.
        var newlineCount = 0
        
        for (i, char) in string.unicodeScalars.enumerated() {
            guard char != Unicode.Scalar("\n") else { // newline
                cursorY -= fontMetrics.height * scale * lineSpacing
                
                alignLine(&lineVertices, withAlignment: alignment, lineWidth: cursorX)
                vertices.append(contentsOf: lineVertices)
                
                cursorX = 0
                newlineCount += 1
                lineVertices = []
                continue
            }
            
            guard let glyph = fontMetrics.glyphData["\(char)"] else {
                cursorX += fontMetrics.spaceAdvance * scale
                continue
            }
            
            let uvKey = String(format: "0x%04X", char.value).lowercased()
            guard let uvData = (atlasData["frames"] as! Dictionary<String, Dictionary<String, NSNumber>>)[uvKey] else {
                fatalError("No UV-coordinates for character '\(char)'!")
            }

            if (i > 0) {
                let strIndex = string.index(string.startIndex, offsetBy: i - 1)
                let kernChar = String(string[strIndex])
                let kernVal = glyph.kernings[kernChar] ?? 0.0
                if (kernVal != 0.0 && (kernVal < -0.001 || kernVal > 0.001)) {
                    cursorX += kernVal * scale;
                }
            }

            let glyphWidth    = glyph.bboxWidth * scale;
            let glyphHeight   = glyph.bboxHeight * scale;
            let glyphBearingX = glyph.bearingX * scale;
            let glyphBearingY = glyph.bearingY * scale;
            let glyphAdvanceX = glyph.advanceX * scale;

            let x = cursorX + glyphBearingX;
            let y = cursorY + glyphBearingY;
            let z = Float(i) * 0.001

            if x > maxX { maxX = x }
            if x < minX { minX = x }
            if y > maxY { maxY = y }
            if y < minY { minY = y }
            
            let w = uvData["w"]!.floatValue / textureWidth
            let h = uvData["h"]!.floatValue / textureHeight
            let s0 = uvData["x"]!.floatValue / textureWidth
            let t0 = uvData["y"]!.floatValue / textureHeight
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

            let curidx: UInt16 = UInt16(i - newlineCount) * 4
            indices.append(curidx + 0)
            indices.append(curidx + 1)
            indices.append(curidx + 2) // first triangle
            indices.append(curidx + 1)
            indices.append(curidx + 3)
            indices.append(curidx + 2) // second triangle

            cursorX += glyphAdvanceX
        }
        
        // Add the last line too.
        alignLine(&lineVertices, withAlignment: alignment, lineWidth: cursorX)
        vertices.append(contentsOf: lineVertices)

        // Center align the vertices vertically
        let height = maxY - minY
        let width = maxX - minX

        vertices = vertices.map {
            (vertex: Vertex) in
            var vertex = vertex
            vertex.y -= height / 2
            
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
    
    private static func loadTexture(for fontNamed: String, bundle: Bundle) {
        let textureLoader = MTKTextureLoader(device: SCNText2D.device)
        let textureLoaderOptions: [MTKTextureLoader.Option: Any] = [
            .SRGB : false
        ]
        
        let mdlTexture = MDLTexture(named: "\(fontNamed).png", bundle: bundle)!
        let texture = try! textureLoader.newTexture(texture: mdlTexture, options: textureLoaderOptions)
        SCNText2D.textureCache[fontNamed] = texture
    }
    
    private static func loadFontMetrics(for fontNamed: String, bundle: Bundle) {
        let jsonURL = bundle.url(forResource: fontNamed, withExtension: "json")!
        let jsonData = try! Data(contentsOf: jsonURL)
        
        let metrics = try! JSONDecoder().decode(FontMetrics.self, from: jsonData)
        
        SCNText2D.metricsCache[fontNamed] = metrics
    }
    
    private static func loadAtlasData(for fontNamed: String, bundle: Bundle) {
        let atlasDataURL = bundle.url(forResource: fontNamed, withExtension: "plist")!
        let atlas = NSDictionary(contentsOfFile: atlasDataURL.path) as! AtlasData
        
        SCNText2D.atlasCache[fontNamed] = atlas
    }
}

