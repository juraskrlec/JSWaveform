//
//  WaveformConfiguration.swift
//
//
//  Created by Jura Skrlec on 23.06.2024.
//

import Foundation
import SwiftUI

public enum AudioPlayer {
    
    public struct Style: Equatable, Sendable {
        
        public struct PlayButtonConfig: Equatable, Sendable {
            public let playImage: Image
            public let pauseImage: Image
            public let width: CGFloat
            
            public init(playImage: Image = Image.play, pauseImage: Image = Image.pause, width: CGFloat = 40) {
                self.playImage = playImage
                self.pauseImage = pauseImage
                self.width = width
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
            public let width: CGFloat
            
            public init(tintColor: Color = .gray, width: CGFloat = 40) {
                self.tintColor = tintColor
                self.width = width
            }
        }
    }
    
    public struct Configuration: Equatable, Sendable {
        public let playButtonConfig: Style.PlayButtonConfig
        public let geometryConfig: Style.GeometryConfig
        public let draggableCircleConfig: Style.DragableCircleConfig
        public let timeEffectButtonConfig: Style.TimeEffectButtonConfig
        public let backgroundColor: Color
        public let downsampleNumber: Int
        public let playSpacerLength: CGFloat
        public let effectSpacerLength: CGFloat
        
        public init(
            images: Style.PlayButtonConfig = Style.PlayButtonConfig(),
            geometryConfig: Style.GeometryConfig = Style.GeometryConfig(),
            draggableCircleConfig: Style.DragableCircleConfig = Style.DragableCircleConfig(),
            timeEffectButtonConfig: Style.TimeEffectButtonConfig = Style.TimeEffectButtonConfig(),
            backgroundColor: Color = .clear,
            downsampleNumber: Int = 20,
            playSpacerLength: CGFloat = 16,
            effectSpacerLength: CGFloat = 16) {
                
                self.playButtonConfig = images
                self.geometryConfig = geometryConfig
                self.draggableCircleConfig = draggableCircleConfig
                self.timeEffectButtonConfig = timeEffectButtonConfig
                self.backgroundColor = backgroundColor
                self.downsampleNumber = downsampleNumber
                self.playSpacerLength = playSpacerLength
                self.effectSpacerLength = effectSpacerLength
        }
    }
}
