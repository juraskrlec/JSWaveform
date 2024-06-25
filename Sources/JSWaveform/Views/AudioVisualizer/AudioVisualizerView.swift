//
//  AudioVisualizerView.swift
//
//
//  Created by Jura Skrlec on 23.06.2024.
//

import SwiftUI

public struct AudioVisualizerView<Content: View>: View {
    
    // - MARK: Public
    @State var audioURL: URL
    
    // - MARK: Private
    @State private var audioVisualizerViewModel: AudioVisualizerViewModel
    private let configuration: AudioVisualizer.Configuration
    private let priority: TaskPriority
    private let content: (AudioVisualizerShape) -> Content
    
    /// Initialize AudioVisualizerView
    ///
    /// - Parameters:
    ///     - audioURL: Audio file URL
    ///     - priority: Task qos
    ///
    /// - Returns: Intialized AudioVisualizerView
    public init(audioURL: URL,
         configuration: AudioVisualizer.Configuration = AudioVisualizer.Configuration(),
         priority: TaskPriority = .userInitiated,
         @ViewBuilder content: @escaping (AudioVisualizerShape) -> Content) {
        self.audioURL = audioURL
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
            update(audioURL: audioURL)
        }
        .onChange(of: audioURL) { _, newValue in
            update(audioURL: newValue)
        }
        .background(.clear)
        .animation(.linear(duration: 0.1), value: audioVisualizerViewModel.amplitudes)
    }
    
    private func update(audioURL url: URL) {
        Task(priority: priority) {
            do {
                if audioVisualizerViewModel.isAudioPlayerPlaying {
                    audioVisualizerViewModel.stopAudioPlayer()
                }
                try await audioVisualizerViewModel.setAudioEngine(forURL: url)
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
    
    /// Use this to stop playing file.
    public func stopAudio() {
        audioVisualizerViewModel.stopAudioPlayer()
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
