//
//  FontMetrics.swift
//  SCNText2D
//
//  Created by Teemu Harju on 10/02/2019.
//

import Foundation

class FontMetrics: Codable {

    enum CodingKeys: String, CodingKey {
        case centerOffset = "CenterOffset"
        case edgeWidth = "EdgeWidth"
        case fontHeight = "FontHeight"
        case horizontalPad = "HorizontalPad"
        case naturalHeight = "NaturalHeight"
        case naturalWidth = "NaturalWidth"
        case numGlyphs = "NumGlyphs"
        case tweakScale = "TweakScale"
        case version = "Version"
        case verticalPad = "VerticalPad"
        case glyphs = "Glyphs"
    }
    
    let centerOffset: Float
    let edgeWidth: Float
    let fontHeight: Float
    let horizontalPad: Float
    let naturalHeight: Float
    let naturalWidth: Float
    let numGlyphs: Int
    let tweakScale: Float
    let version: Float
    let verticalPad: Float
    let glyphs: [GlyphData]
    
    // Glyphs are populated here when font is loaded.
    var glyphMap: [Unicode.Scalar: GlyphData] = [:]
    var maxAscent: Float = 0.0
    var maxDescent: Float = 0.0
}
