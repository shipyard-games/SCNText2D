//
//  FontMetrics.swift
//  SCNText2D
//
//  Created by Teemu Harju on 10/02/2019.
//

import Foundation

struct FontMetrics: Codable {

    enum CodingKeys: String, CodingKey {
        case ascender
        case descender
        case glyphData = "glyph_data"
        case height
        case maxAdvance = "max_advance"
        case name
        case size
        case spaceAdvance = "space_advance"
    }

    var ascender: Float
    var descender: Float
    var glyphData: [String : GlyphData]
    var height: Float
    var maxAdvance: Float
    var name: String
    var size: Int
    var spaceAdvance: Float
}
