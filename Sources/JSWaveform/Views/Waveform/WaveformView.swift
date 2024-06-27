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

public struct WaveformView: View {
        
    @State private var waveformViewModel: WaveformViewModel
    @State private var samples: [Float] = []
    @State private var colors: [Color] = []
    @GestureState private var isDetectingLongPress = false
    @State private var completedLongPress = false
    @State private var isDragging: Bool = false
    @State private var startDragPosition: Double = 0
    @State private var endDragPosition: Double = 0
    
    private let configuration: Waveform.Configuration
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
                configuration: Waveform.Configuration = Waveform.Configuration(),
                priority: TaskPriority = .userInitiated) {
        self.waveformViewModel = WaveformViewModel(audioURL: audioURL)
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
                Spacer(minLength: 32)
                GeometryReader { geometry in
                    let totalSpacing = configuration.geometryConfig.spacing * CGFloat(samples.count - 1)
                    let width = (geometry.size.width - totalSpacing) / CGFloat(samples.count)
                    let height = geometry.size.height
                    
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
                }
                .onAppear {
                    update(audioURL: waveformViewModel.audioURL)
                }
                .onChange(of: waveformViewModel.audioURL) { _, newValue in
                    update(audioURL: newValue)
                }
                .onChange(of: waveformViewModel.audioProgress) { _, newValue in
                    animatePosition()
                }
                Spacer(minLength: 16)
                Button(waveformViewModel.currentAudioPlayback.label) {
                    waveformViewModel.updateAudioPlayback()
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(.gray)
            }
            HStack {
                Text(waveformViewModel.audioTime.elapsedText)
                Spacer()
                Text(waveformViewModel.audioTime.audioLengthText)
            }
        }
    }
    
    /// USe this to update audio with different audio file.
    public func updateAudio(forURL url: URL) {
        waveformViewModel.audioURL = url
    }
    
    private func update(audioURL url: URL) {
        Task(priority: priority) {
            do {
                let samples = try await waveformViewModel.waveformSamples(forURL: url, downsampledTo: configuration.downsampleNumber, priority: priority)
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
        let newPosition = Double(endDragPosition) * Double(waveformViewModel.audioLengthSamples)
        let newTime = newPosition * waveformViewModel.audioLengthSeconds / Double(waveformViewModel.audioLengthSamples)
        let doubleDownTime = floor(newTime)
        var time: Double
        if doubleDownTime.isZero {
            time = -waveformViewModel.audioTime.elapsedTime
        }
        else if doubleDownTime.isLessThanOrEqualTo(waveformViewModel.audioTime.elapsedTime) {
            time = -(waveformViewModel.audioTime.elapsedTime - doubleDownTime)
        }
        else {
            time = doubleDownTime - waveformViewModel.audioTime.elapsedTime
        }

        waveformViewModel.seekEnd(to: time)
    }
    
    private func handleOnLongPressStarted() {
        waveformViewModel.seekBegin()
    }
    
    private func handleOnLongPressEndeed() {
    }
}
