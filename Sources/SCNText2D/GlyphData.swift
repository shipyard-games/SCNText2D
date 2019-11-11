//
//  GlyphData.swift
//  SCNText2D
//
//  Created by Teemu Harju on 10/02/2019.
//

import Foundation

class GlyphData: Codable {

    enum CodingKeys: String, CodingKey {
        case advanceX = "AdvanceX"
        case advanceY = "AdvanceY"
        case height = "Height"
        case width = "Width"
        case bearingX = "BearingX"
        case bearingY = "BearingY"
        case charCode = "CharCode"
        case x = "X"
        case y = "Y"
    }

    let advanceX: Float
    let advanceY: Float
    let height: Float
    let width: Float
    let bearingX: Float
    let bearingY: Float
    let charCode: Int
    let x: Float
    let y: Float
}
