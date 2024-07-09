//
//  WaveformView.swift
//
//
//  Created by Jura Skrlec on 23.06.2024.
//

import SwiftUI

public struct DraggableCircle: View {
        
    @Binding var position: Double
    @Binding var endPosition: Double
    
    @GestureState private var isDetectingLongPress = false
    @State private var completedLongPress = false
    let containerWidth: CGFloat
    let width: CGFloat
    let height: CGFloat
    let color: Color
    var onDragStarted: () -> Void
    var onDragEnded: () -> Void
    var onLongPressStarted: () -> Void
    var onLongPressEnded: () -> Void
    
    public var body: some View {
        Circle()
            .fill(color)
            .frame(width: width, height: height)
            .offset(x: position * containerWidth - 10)
            .gesture(
                longPressGesture.sequenced(before: dragGesture)
            )
    }
    
    var longPressGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.1)
            .updating($isDetectingLongPress) { currentState, gestureState,
                    transaction in
                gestureState = currentState
                self.onLongPressStarted()
            }
            .onEnded { finished in
                self.completedLongPress = finished
                self.onLongPressEnded()
            }
    }
    
    var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                self.position = min(max(0, value.location.x / self.containerWidth), 1)
            }
            .onEnded({ value in
                self.endPosition = min(max(0, value.location.x / self.containerWidth), 1)
                self.onDragEnded()
            })
    }
}

@MainActor
public struct AudioPlayerView: View {
        
    @State private var waveformViewModel: AudioPlayerModel
    @State private var samples: [Float] = []
    @State private var colors: [Color] = []
    @GestureState private var isDetectingLongPress = false
    @State private var completedLongPress = false
    @State private var isDragging: Bool = false
    @State private var startDragPosition: Double = 0
    @State private var endDragPosition: Double = 0
    @State private var isLoading: Bool = false
    
    private let configuration: AudioPlayer.Configuration
    private let priority: TaskPriority

    /// Initialize JSWaveformView
    ///
    /// - Parameters:
    ///     - audioURL: Audio file URL
    ///     - configuration: View configuration
    ///     - proprity: Task qos
    ///
    /// - Returns: Intialized WaveformView
    public init(audioURL: URL,
                configuration: AudioPlayer.Configuration = AudioPlayer.Configuration(),
                priority: TaskPriority = .userInitiated) {
        self.waveformViewModel = AudioPlayerModel(audioURL: audioURL)
        self.configuration = configuration
        self.priority = priority
    }

    public var body: some View {
        VStack {
            HStack(alignment: .center) {
                Button(action: {
                    waveformViewModel.playOrPauseAudioPlayer()
                }) {
                    waveformViewModel.isPlaying ? configuration.images.pause.resizable().scaledToFit() : configuration.images.play.resizable().scaledToFit()
                }
                Spacer(minLength: configuration.playSpacerLength)
                GeometryReader { geometry in
                    let totalSpacing = configuration.geometryConfig.spacing * CGFloat(samples.count - 1)
                    let width = (geometry.size.width - totalSpacing) / CGFloat(samples.count)
                    let height = geometry.size.height
                    
                    VStack {
                        ZStack(alignment: .leading) {
                            HStack(spacing: configuration.geometryConfig.spacing) {
                                ForEach(samples.indices, id: \.self) { index in
                                    RoundedRectangle(cornerRadius: configuration.geometryConfig.cornerRadius)
                                        .fill(colors[index])
                                        .frame(width: width, height: CGFloat(samples[index]) * height)
                                }
                            }
                            DraggableCircle(position: $waveformViewModel.audioProgress,
                                            endPosition: $endDragPosition,
                                            containerWidth: geometry.size.width,
                                            width: configuration.draggableCircleConfig.width,
                                            height: configuration.draggableCircleConfig.height,
                                            color: configuration.draggableCircleConfig.fillColor,
                                            onDragStarted: handleDragStarted,
                                            onDragEnded: handleDragEnded,
                                            onLongPressStarted: handleOnLongPressStarted,
                                            onLongPressEnded: handleOnLongPressEndeed)
                        }
                        HStack {
                            Text(waveformViewModel.audioTime.elapsedText)
                            Spacer()
                            Text(waveformViewModel.audioTime.audioLengthText)
                        }
                    }

                }
                .onAppear {
                    update()
                }
                .onChange(of: waveformViewModel.audioProgress) { _, newValue in
                    animatePosition()
                }
                Spacer(minLength: configuration.effectSpacerLength)
                Button(waveformViewModel.currentAudioPlayback.label) {
                    waveformViewModel.updateAudioPlayback()
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(configuration.timeEffectButtonConfig.tintColor)
            }
        }
        .onDisappear {
            waveformViewModel.clean()
        }
    }
    
    private func update() {
        Task(priority: priority) {
            do {
                let samples = try await waveformViewModel.loadSamples(downsampledTo: configuration.downsampleNumber)
                await MainActor.run {
                    self.samples = samples
                    self.colors = Array(repeating: configuration.geometryConfig.primaryColor, count: samples.count)
                }
            }
            catch {
                assertionFailure(error.localizedDescription)
            }
        }
    }
    
    private func animatePosition() {
        withAnimation(.linear(duration: 0.1)) {
            for i in 0..<samples.count {
                if i < waveformViewModel.activeSamplesCount {
                    colors[i] = configuration.geometryConfig.secondaryColor
                } else {
                    colors[i] = configuration.geometryConfig.primaryColor
                }
            }
        }
    }
    
    private func handleDragStarted() {
    }
    
    private func handleDragEnded() {
        waveformViewModel.updateTime(for: Double(endDragPosition))
    }
    
    private func handleOnLongPressStarted() {
        waveformViewModel.seekBegin()
    }
    
    private func handleOnLongPressEndeed() {
    }
}
