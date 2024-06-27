//
//  WaveformConfiguration.swift
//
//
//  Created by Jura Skrlec on 23.06.2024.
//

import Foundation
import SwiftUI

public enum Waveform {
    
    public struct Style: Equatable, Sendable {
        
        public struct Images: Equatable, Sendable {
            public let play: Image
            public let pause: Image
            
            public init(play: Image = Image.play, pause: Image = Image.pause) {
                self.play = play
                self.pause = pause
            }
        }
        
        public struct GeometryConfig: Equatable, Sendable {
            public let primaryColor: Color
            public let secondaryColor: Color
            public let cornerRadius: CGFloat
            public let spacing: CGFloat
            
            public init(primaryColor: Color = .gray, secondaryColor: Color = .green, cornerRadius: CGFloat = 3, spacing: CGFloat = 2) {
                self.primaryColor = primaryColor
                self.secondaryColor = secondaryColor
                self.cornerRadius = cornerRadius
                self.spacing = spacing
            }
        }
        
        public struct DragableCircleConfig: Equatable, Sendable {
            public let fillColor: Color
            public let width: CGFloat
            public let height: CGFloat
            
            public init(fillColor: Color = .blue, width: CGFloat = 20, height: CGFloat = 20) {
                self.fillColor = fillColor
                self.width = width
                self.height = height
            }
        }
        
        public struct TimeEffectButtonConfig: Equatable, Sendable {
            public let tintColor: Color
            
            public init(tintColor: Color = .gray) {
                self.tintColor = tintColor
            }
        }
    }
    
    public struct Configuration: Equatable, Sendable {
        public let images: Style.Images
        public let geometryConfig: Style.GeometryConfig
        public let draggableCircleConfig: Style.DragableCircleConfig
        public let timeEffectButtonConfig: Style.TimeEffectButtonConfig
        public let backgroundColor: Color
        public let downsampleNumber: Int
        
        public init(
            images: Style.Images = Style.Images(),
            geometryConfig: Style.GeometryConfig = Style.GeometryConfig(),
            draggableCircleConfig: Style.DragableCircleConfig = Style.DragableCircleConfig(),
            timeEffectButtonConfig: Style.TimeEffectButtonConfig = Style.TimeEffectButtonConfig(),
            backgroundColor: Color = .clear,
            downsampleNumber: Int = 20) {
                
                self.images = images
                self.geometryConfig = geometryConfig
                self.draggableCircleConfig = draggableCircleConfig
                self.timeEffectButtonConfig = timeEffectButtonConfig
                self.backgroundColor = backgroundColor
                self.downsampleNumber = downsampleNumber
        }
    }
}
