//
//  GlyphData.swift
//  SCNText2D
//
//  Created by Teemu Harju on 10/02/2019.
//

import Foundation

struct GlyphData: Codable {

    enum CodingKeys: String, CodingKey {
        case advanceX = "advance_x"
        case bboxHeight = "bbox_height"
        case bboxWidth = "bbox_width"
        case bearingX = "bearing_x"
        case bearingY = "bearing_y"
        case charcode
        case kernings
        case s0
        case s1
        case t0
        case t1
    }

    var advanceX: Float
    var bboxHeight: Float
    var bboxWidth: Float
    var bearingX: Float
    var bearingY: Float
    var charcode: String
    var kernings: [String : Float]
    var s0: Float
    var s1: Float
    var t0: Float
    var t1: Float
}
