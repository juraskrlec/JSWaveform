//
//  AudioVisualizerShape.swift
//
//
//  Created by Jura Skrlec on 23.06.2024.
//

import SwiftUI

public struct AudioVisualizerShape: Shape {
    var amplitudes: [Double]
    private let configuration: AudioVisualizer.ShapeConfig
    
    var animatableData: [Double] {
        get { amplitudes }
        set { amplitudes = newValue }
    }
    
    public init(amplitudes: [Double], configuration: AudioVisualizer.ShapeConfig) {
        self.amplitudes = amplitudes
        self.configuration = configuration
    }
    
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = Double(rect.width)
        let height = Double(rect.height)
        let midHeight: Double
        if configuration.isOneSide {
            midHeight = height
        }
        else {
            midHeight = height / 2
        }
        let barWidth = width / Double(amplitudes.count)
        
        for (index, amplitude) in amplitudes.enumerated() {
            let x = Double(index) * barWidth
            let barHeight = amplitude * height
            let barRect = CGRect(x: x, y: midHeight - barHeight / 2, width: barWidth - 2, height: barHeight)
            path.addRoundedRect(in: barRect, cornerSize: CGSize(width: barWidth / 4, height: barWidth / 4))
        }
        
        return path
    }
}
