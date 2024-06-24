//
//  AudioLevel.swift
//
//
//  Created by Jura Skrlec on 23.06.2024.
//

import Foundation

struct AudioLevels {
    let level: Float
    let peakLevel: Float
}

protocol AudioLevelProvider {
    var levels: AudioLevels { get }
}

class AudioLevel {
    
    var level: CGFloat = 0
    var peakLevel: CGFloat = 0
    var isActive = false
    
    var levelProvider: AudioLevelProvider?
    
    func reset() {
        level = 0
        peakLevel = 0
    }
}
