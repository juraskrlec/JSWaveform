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
    
    public struct ShapeConfig: Equatable, Sendable {
        public let isOneSide: Bool
        
        public init(isOneSide: Bool = false) {
            self.isOneSide = isOneSide
        }
    }
    
    public struct Configuration: Equatable, Sendable {
        
        public let style: Style
        public let animationType: AnimationType
        public let maxNumberOfAmplitudes: Int
        public let shapeConfig: ShapeConfig
        
        public init(
            style: Style = .maskedGradient(.gray),
            animationType: AnimationType = .symetricMiddleHigh,
            maxNumberOfAmplitudes: Int = 10,
            shapeConfig: ShapeConfig = ShapeConfig()) {
            self.style = style
            self.animationType = animationType
            self.maxNumberOfAmplitudes = maxNumberOfAmplitudes
            self.shapeConfig = shapeConfig
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
