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
    
    public struct Configuration: Equatable, Sendable {
        
        public let style: Style
        
        public init(style: Style) {
            self.style = style
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
