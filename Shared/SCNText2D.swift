//
//  SCNText2D.swift
//  SCNText2D
//
//  Created by Teemu Harju on 10/02/2019.
//

import Foundation
import SceneKit

public class SCNText2D {

    public static func create(from string: String, withFontNamed fontNamed: String) -> SCNGeometry {
        let jsonURL = Bundle(for: SCNText2D.self).url(forResource: fontNamed, withExtension: "json")!
        let jsonData = try! Data(contentsOf: jsonURL)

        let fontMetrics = try! JSONDecoder().decode(FontMetrics.self, from: jsonData)

        let shaderLibraryUrl = Bundle(for: SCNText2D.self).url(forResource: "SCNText2D-Shaders", withExtension: "metallib")!

        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError( "Failed to get the system's default Metal device." )
        }

        let shaderLibrary = try! device.makeLibrary(URL: shaderLibraryUrl)

        let shaderProgram = SCNProgram()
        shaderProgram.vertexFunctionName = "sdfTextVertex"
        shaderProgram.fragmentFunctionName = "sdfTextFragment"
        shaderProgram.isOpaque = false
        shaderProgram.library = shaderLibrary

        let geometry = buildGeometry(string, fontMetrics)
        geometry.materials.first?.program = shaderProgram

        if let url = Bundle(for: SCNText2D.self).url(forResource: fontNamed, withExtension: "png") {
            #if os(iOS)
            let fontTexture = UIImage(contentsOfFile: url.path)
            #elseif os(macOS)
            let fontTexture = NSImage(contentsOf: url)
            #endif

            if let fontTexture = fontTexture {
                geometry.materials.first?.setValue(SCNMaterialProperty(contents: fontTexture), forKey: "fontTexture")
            }
        }

        return geometry
    }

    private static func buildGeometry(_ string: String, _ fontMetrics: FontMetrics) -> SCNGeometry {
        let fontSize: SCNFloat = 1.0

        var cursorX: SCNFloat = 0.0
        var cursorY: SCNFloat = 0.0

        var vertices = [SCNVector3]()
        vertices.reserveCapacity(string.count * 4)

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
        
        for (i, char) in string.enumerated() {
            guard char != "\n" else {
                cursorY -= SCNFloat(fontMetrics.height)
                cursorX = 0
                newlineCount += 1
                continue
            }
            
            guard let glyph = fontMetrics.glyphData["\(char)"] else {
                cursorX += SCNFloat(fontMetrics.spaceAdvance)
                continue
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
            let z = SCNFloat(i) * 0.0001

            if x > maxX { maxX = x }
            if x < minX { minX = x }
            if y > maxY { maxY = y }
            if y < minY { minY = y }
            
            let v1 = SCNVector3(x, y - glyphHeight, z)
            let v2 = SCNVector3(x + glyphWidth, y - glyphHeight, z)
            let v3 = SCNVector3(x, y, z)
            let v4 = SCNVector3(x + glyphWidth, y, z)
            
            vertices.append(v1)
            vertices.append(v2)
            vertices.append(v3)
            vertices.append(v4)

            texCoords.append(CGPoint(x: CGFloat(glyph.s0), y: 1.0 - CGFloat(glyph.t1)))
            texCoords.append(CGPoint(x: CGFloat(glyph.s1), y: 1.0 - CGFloat(glyph.t1)))
            texCoords.append(CGPoint(x: CGFloat(glyph.s0), y: 1.0 - CGFloat(glyph.t0)))
            texCoords.append(CGPoint(x: CGFloat(glyph.s1), y: 1.0 - CGFloat(glyph.t0)))

            let curidx: UInt16 = UInt16(i - newlineCount) * 4
            indices.append(curidx + 0)
            indices.append(curidx + 1)
            indices.append(curidx + 2) // first triangle
            indices.append(curidx + 1)
            indices.append(curidx + 3)
            indices.append(curidx + 2) // second triangle

            cursorX += glyphAdvanceX
        }

        // Center align the vertices
        let width = maxX - minX
        let height = maxY - minY

        vertices = vertices.map {
            (vertex: SCNVector3) in

            var vertex = vertex

            vertex.x -= width / 2
            vertex.y -= height / 2

            return vertex
        }

        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let vertexSource = SCNGeometrySource(vertices: vertices)
        let uvSource = SCNGeometrySource(textureCoordinates: texCoords)

        let geometry = SCNGeometry(sources: [vertexSource, uvSource], elements: [element])

        return geometry
    }
}

