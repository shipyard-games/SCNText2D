//
//  AtlasData.swift
//  SCNText2D
//
//  Created by Teemu Harju on 15/05/2019.
//

import Foundation

class AtlasMetaData: Codable {
    
    let width: Float
    let height: Float
    let image: String
}

class AtlasData: Codable {
    
    let meta: AtlasMetaData
    let frames: Dictionary<String, Dictionary<String, Float>>
}
