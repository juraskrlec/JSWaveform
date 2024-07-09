//
//  AudioVisualizerView.swift
//
//
//  Created by Jura Skrlec on 23.06.2024.
//

import SwiftUI

@MainActor
public struct AudioVisualizerView<Content: View>: View {
    
    @State private var audioVisualizerViewModel: AudioVisualizerViewModel
    private let configuration: AudioVisualizer.Configuration
    private let priority: TaskPriority
    private let content: (AudioVisualizerShape) -> Content
    
    /// Initialize AudioVisualizerView
    ///
    /// - Parameters:
    ///     - audioURL: Audio file URL
    ///     - configuration: View configuration
    ///     - priority: Task qos
    ///     - content: Custom shape
    ///
    /// - Returns: Intialized AudioVisualizerView
    public init(
        audioURL: URL,
        configuration: AudioVisualizer.Configuration = AudioVisualizer.Configuration(),
        priority: TaskPriority = .userInitiated,
        @ViewBuilder content: @escaping (AudioVisualizerShape) -> Content) {
        self.configuration = configuration
        self.audioVisualizerViewModel = AudioVisualizerViewModel(audioURL: audioURL, maxNumberOfAmplitudes: configuration.maxNumberOfAmplitudes, animationType: configuration.animationType)
        self.priority = priority
        self.content = content
    }
    
    public var body: some View {
        VStack {
            content(AudioVisualizerShape(amplitudes: audioVisualizerViewModel.amplitudes))
        }
        .onAppear {
            update(audioURL: audioVisualizerViewModel.audioURL)
        }
        .onDisappear {
            audioVisualizerViewModel.clean()
        }
        .background(.clear)
        .animation(.linear(duration: 0.1), value: audioVisualizerViewModel.amplitudes)
    }
    
    private func update(audioURL url: URL) {
        Task(priority: priority) {
            do {
                try await audioVisualizerViewModel.prepareAudioEngine(priority: priority)
                await audioVisualizerViewModel.processAudio()
            }
            catch {
                assertionFailure(error.localizedDescription)
            }
        }
    }
    
    /// Use this to play file.
    public func playAudio() {
        audioVisualizerViewModel.playAudioPlayer()
    }
    
    /// Use this to stop file.
    public func stopAudio() {
        audioVisualizerViewModel.stopAudioPlayer()
    }
    
    /// Use this to pause file.
    public func pauseAudio() {
        audioVisualizerViewModel.pauseAudioPlayer()
    }
    
    /// Use this to update audio with different audio file.
    public func updateAudio(forURL url: URL) {
        audioVisualizerViewModel.audioURL = url
    }
}

public extension AudioVisualizerView {
    init(
        audioURL: URL,
        configuration: AudioVisualizer.Configuration = AudioVisualizer.Configuration(),
        priority: TaskPriority = .userInitiated
    ) where Content == AnyView {
        self.init(audioURL: audioURL, configuration: configuration, priority: priority) { shape in
            AnyView(AudioVisualizerShapeStyler().style(forShape: shape, for: configuration))
        }
    }
}
