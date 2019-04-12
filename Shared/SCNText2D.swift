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
    
    typealias AtlasData = Dictionary<String, Any>
    
    public enum TextAlignment {
        case left
        case right
        case centered
    }

    public static func create(from string: String, withFontNamed fontName: String, alignment: TextAlignment = .centered) -> SCNGeometry {
        let jsonURL = Bundle.main.url(forResource: fontName, withExtension: "json")!
        let jsonData = try! Data(contentsOf: jsonURL)

        let fontMetrics = try! JSONDecoder().decode(FontMetrics.self, from: jsonData)
        
        let atlasDataURL = Bundle.main.url(forResource: fontName, withExtension: "plist")!
        let atlasData = NSDictionary(contentsOfFile: atlasDataURL.path) as! AtlasData

        let shaderLibraryUrl = Bundle(for: SCNText2D.self).url(forResource: "SCNText2D-Shaders", withExtension: "metallib")!

        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError( "Failed to get the system's default Metal device." )
        }

        let shaderLibrary = try! device.makeLibrary(URL: shaderLibraryUrl)

        let shaderProgram = SCNProgram()
        shaderProgram.vertexFunctionName = "distanceShadowVertex"
        shaderProgram.fragmentFunctionName = "distanceShadowFrag"
        shaderProgram.isOpaque = false
        shaderProgram.library = shaderLibrary

        let geometry = buildGeometry(string, fontMetrics, atlasData, alignment)
        geometry.materials.first?.program = shaderProgram

        let textureLoader = MTKTextureLoader(device: device)
        let textureLoaderOptions: [MTKTextureLoader.Option: Any] = [
            .SRGB : false
        ]
        
        let mdlTexture = MDLTexture(named: "\(fontName).png")!
        let sdfTexture = try! textureLoader.newTexture(texture: mdlTexture, options: textureLoaderOptions)
        geometry.materials.first?.program = shaderProgram
        geometry.materials.first?.setValue(SCNMaterialProperty(contents: sdfTexture), forKey: "diffuseTexture")
        geometry.materials.first?.setValue(0.04, forKey: "smoothing")
        #if os(iOS)
        geometry.materials.first?.setValue(UIColor.red, forKey: "textColor")
        geometry.materials.first?.setValue(UIColor.white, forKey: "borderColor")
        #elseif os(macOS)
        geometry.materials.first?.setValue(NSColor.red, forKey: "textColor")
        geometry.materials.first?.setValue(NSColor.white, forKey: "borderColor")
        #endif
        return geometry
    }

    private static func buildGeometry(_ string: String, _ fontMetrics: FontMetrics, _ atlasData: AtlasData, _ alignment: TextAlignment) -> SCNGeometry {
        let fontSize: SCNFloat = 1.0
        
        let atlasMeta = atlasData["meta"] as! Dictionary<String, Any>
        
        let textureWidth = (atlasMeta["width"] as! NSNumber).floatValue
        let textureHeight = (atlasMeta["height"] as! NSNumber).floatValue

        var cursorX: SCNFloat = 0.0
        var cursorY: SCNFloat = 0.0

        var vertices = [SCNVector3]()
        vertices.reserveCapacity(string.count * 4)
        
        var lineVertices = [SCNVector3]()

        var texCoords = [CGPoint]()
        texCoords.reserveCapacity(vertices.count)

        var indices = [UInt16]()
        indices.reserveCapacity(string.count * 6)

        var minX: SCNFloat = SCNFloat.infinity
        var minY: SCNFloat = SCNFloat.infinity
        var maxX: SCNFloat = -SCNFloat.infinity
        var maxY: SCNFloat = -SCNFloat.infinity

        // We keep track of the number of newlines, since they don't generate any
        // vertices like all other glyphs do. We use this count to adjust the indices
        // of the test geometry.
        var newlineCount = 0
        
        for (i, char) in string.unicodeScalars.enumerated() {
            guard char != Unicode.Scalar("\n") else { // newline
                cursorY -= SCNFloat(fontMetrics.height)
                
                alignLine(&lineVertices, withAlignment: alignment, lineWidth: cursorX)
                vertices.append(contentsOf: lineVertices)
                
                cursorX = 0
                newlineCount += 1
                lineVertices = []
                continue
            }
            
            guard let glyph = fontMetrics.glyphData["\(char)"] else {
                cursorX += SCNFloat(fontMetrics.spaceAdvance)
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
                    cursorX += SCNFloat(kernVal) * fontSize;
                }
            }

            let glyphWidth    = SCNFloat(glyph.bboxWidth) * fontSize;
            let glyphHeight   = SCNFloat(glyph.bboxHeight) * fontSize;
            let glyphBearingX = SCNFloat(glyph.bearingX) * fontSize;
            let glyphBearingY = SCNFloat(glyph.bearingY) * fontSize;
            let glyphAdvanceX = SCNFloat(glyph.advanceX) * fontSize;

            let x = cursorX + glyphBearingX;
            let y = cursorY + glyphBearingY;
            let z = SCNFloat(i) * 0.001

            if x > maxX { maxX = x }
            if x < minX { minX = x }
            if y > maxY { maxY = y }
            if y < minY { minY = y }
            
            let v1 = SCNVector3(x, y - glyphHeight, z)
            let v2 = SCNVector3(x + glyphWidth, y - glyphHeight, z)
            let v3 = SCNVector3(x, y, z)
            let v4 = SCNVector3(x + glyphWidth, y, z)
            
            lineVertices.append(v1)
            lineVertices.append(v2)
            lineVertices.append(v3)
            lineVertices.append(v4)
            
            let w = uvData["w"]!.floatValue / textureWidth
            let h = uvData["h"]!.floatValue / textureHeight
            let s0 = uvData["x"]!.floatValue / textureWidth
            let t0 = uvData["y"]!.floatValue / textureHeight
            let s1 = s0 + w
            let t1 = t0 + h
            
            texCoords.append(CGPoint(x: CGFloat(s0), y: CGFloat(t1)))
            texCoords.append(CGPoint(x: CGFloat(s1), y: CGFloat(t1)))
            texCoords.append(CGPoint(x: CGFloat(s0), y: CGFloat(t0)))
            texCoords.append(CGPoint(x: CGFloat(s1), y: CGFloat(t0)))

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
            (vertex: SCNVector3) in
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

        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let vertexSource = SCNGeometrySource(vertices: vertices)
        let uvSource = SCNGeometrySource(textureCoordinates: texCoords)

        let geometry = SCNGeometry(sources: [vertexSource, uvSource], elements: [element])

        return geometry
    }
    
    private static func alignLine(_ lineVertices: inout [SCNVector3], withAlignment alignment: TextAlignment, lineWidth: SCNFloat) {
        switch (alignment) {
        case .centered:
            lineVertices = lineVertices.map {
                (vertex: SCNVector3) -> SCNVector3 in
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
                (vertex: SCNVector3) -> SCNVector3 in
                var vertex = vertex
                vertex.x -= lineWidth
                return vertex
            }
        }
    }
}

