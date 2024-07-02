//
//  AudioVisualizerConfiguration.swift
//
//
//  Created by Jura Skrlec on 23.06.2024..
//

import Foundation
import SwiftUI

public enum AudioVisualizer {
    
    public enum Style: Equatable, Sendable {
        case filled(Color, Color)
        case gradient([Color])
        case maskedGradient(Color)
    }
    
    public enum AnimationType: Equatable, Sendable {
        case equal
        case lowToHigh
        case highToLow
        case symetricMiddleHigh
        case symetricMiddleLow
    }
    
    public struct Configuration: Equatable, Sendable {
        
        public let style: Style
        public let animationType: AnimationType
        public let maxNumberOfAmplitudes: Int
        
        public init(
            style: Style = .maskedGradient(.gray),
            animationType: AnimationType = .symetricMiddleHigh,
            maxNumberOfAmplitudes: Int = 10) {
            self.style = style
            self.animationType = animationType
            self.maxNumberOfAmplitudes = maxNumberOfAmplitudes
        }
    }
}

public struct AudioVisualizerShapeStyler {
    @ViewBuilder
    func style(forShape shape: AudioVisualizerShape, for configuration: AudioVisualizer.Configuration) -> some View {
        switch configuration.style {
        case .filled(let fillColor, let strokeColor):
            shape
                .fill(fillColor)
                .stroke(strokeColor)
        case .gradient(let colors):
            shape
                .fill(LinearGradient(colors: colors.map(Color.init), startPoint: .bottom, endPoint: .top))
        case .maskedGradient(let color):
            shape
                .fill(color)
                .stroke(color)
                .mask((LinearGradient(gradient: Gradient(colors: [.clear, color, .clear]), startPoint: .leading, endPoint: .trailing)))
        }
    }
}
