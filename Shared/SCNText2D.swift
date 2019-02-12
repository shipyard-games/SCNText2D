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
        let jsonURL = Bundle.main.url(forResource: fontNamed, withExtension: "json")!
        let jsonData = try! Data(contentsOf: jsonURL)

        let fontMetrics = try! JSONDecoder().decode(FontMetrics.self, from: jsonData)

        let shaderProgram = SCNProgram()
        shaderProgram.vertexFunctionName = "sdfTextVertex"
        shaderProgram.fragmentFunctionName = "sdfTextFragment"
        shaderProgram.isOpaque = false

        let geometry = buildGeometry(string, fontMetrics)
        geometry.materials.first?.program = shaderProgram

        if let url = Bundle.main.url(forResource: fontNamed, withExtension: "png") {
            #if os(iOS)
            let fontTexture = UIImage(contentsOf: url)
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
        let fontSize: Float = 1.0

        var cursorX: Float = 0.0
        let cursorY: Float = 0.0

        var vertices = [SCNVector3]()
        vertices.reserveCapacity(string.count * 4)

        var texCoords = [CGPoint]()
        texCoords.reserveCapacity(vertices.count)

        var indices = [UInt16]()
        indices.reserveCapacity(string.count * 6)


        for (i, char) in string.enumerated() {

            guard let glyph = fontMetrics.glyphData["\(char)"] else {
                cursorX += fontMetrics.spaceAdvance
                continue
            }

            if (i > 0) {
                let strIndex = string.index(string.startIndex, offsetBy: i - 1)
                let kernChar = String(string[strIndex])
                let kernVal = glyph.kernings[kernChar] ?? 0.0
                if (kernVal != 0.0 && (kernVal < -0.001 || kernVal > 0.001)) {
                    cursorX += kernVal * fontSize;
                }
            }

            let glyphWidth    = glyph.bboxWidth * fontSize;
            let glyphHeight   = glyph.bboxHeight * fontSize;
            let glyphBearingX = glyph.bearingX * fontSize;
            let glyphBearingY = glyph.bearingY * fontSize;
            let glyphAdvanceX = glyph.advanceX * fontSize;

            let x = cursorX + glyphBearingX;
            let y = cursorY + glyphBearingY;
            let z = Float(i) * 0.0001

            vertices.append(SCNVector3(x, y - glyphHeight, z))
            vertices.append(SCNVector3(x + glyphWidth, y - glyphHeight, z))
            vertices.append(SCNVector3(x, y, z))
            vertices.append(SCNVector3(x + glyphWidth, y, z))

            texCoords.append(CGPoint(x: CGFloat(glyph.s0), y: 1.0 - CGFloat(glyph.t1)))
            texCoords.append(CGPoint(x: CGFloat(glyph.s1), y: 1.0 - CGFloat(glyph.t1)))
            texCoords.append(CGPoint(x: CGFloat(glyph.s0), y: 1.0 - CGFloat(glyph.t0)))
            texCoords.append(CGPoint(x: CGFloat(glyph.s1), y: 1.0 - CGFloat(glyph.t0)))

            let curidx: UInt16 = UInt16(i) * 4
            indices.append(curidx + 0)
            indices.append(curidx + 1)
            indices.append(curidx + 2) // first triangle
            indices.append(curidx + 1)
            indices.append(curidx + 3)
            indices.append(curidx + 2) // second triangle

            cursorX += glyphAdvanceX
        }

        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let vertexSource = SCNGeometrySource(vertices: vertices)
        let uvSource = SCNGeometrySource(textureCoordinates: texCoords)

        let geometry = SCNGeometry(sources: [vertexSource, uvSource], elements: [element])

        return geometry
    }
}

