//
//  WaveformViewModel.swift
//
//
//  Created by Jura Skrlec on 23.06.2024.
//

import Foundation
import AVFoundation
import Observation
import os

private actor AudioPlayerLoader {
    let logger = Logger(subsystem: "JSWaveform.AudioPlayerLoader", category: "ModelIO")
    
    enum WafevormError: Error {
        case bufferRetrieveError
        case audioFileNotFound
    }
    
    func loadSamples(forURL url: URL) async throws -> [Float] {
        logger.debug("Loading audio samples for URL: \(url)")
        
        let file = try? AVAudioFile(forReading: url)
        guard let format = file?.processingFormat, let length = file?.length else {
            throw WafevormError.audioFileNotFound
        }
        
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(length))
        try? file?.read(into: buffer!)
        
        guard let floatChannelData = buffer?.floatChannelData else {
            throw WafevormError.bufferRetrieveError
        }
        let channelData = floatChannelData.pointee
        
        let samples = stride(from: 0, to: Int(length), by: Int(format.channelCount)).map { channelData[$0] }
        return samples
    }
    
    func loadSamples(forURL url: URL, downsampledTo targetSampleCount: Int) async throws -> [Float] {
        logger.debug("Loading audio samples for URL: \(url), downsampled: \(targetSampleCount)")
        
        let file = try? AVAudioFile(forReading: url)
        guard let format = file?.processingFormat, let length = file?.length else { throw WafevormError.audioFileNotFound }
        
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(length))
        try? file?.read(into: buffer!)
        
        guard let floatChannelData = buffer?.floatChannelData else { throw WafevormError.bufferRetrieveError }
        let channelData = floatChannelData.pointee
        
        let sampleCount = Int(length)
        let samplesPerPixel = sampleCount / targetSampleCount
        var downsampledData = [Float]()
        
        for i in 0..<targetSampleCount {
            let start = i * samplesPerPixel
            let end = min((i + 1) * samplesPerPixel, sampleCount)
            let sampleRange = start..<end
            
            let maxSample = sampleRange.map { channelData[$0] }.max() ?? 0
            downsampledData.append(maxSample)
        }
        
        return downsampledData
    }
}

@Observable
@MainActor class AudioPlayerModel: JSModel {
    
    // -MARK: Public
    var audioTime: AudioTime = .zero
    var audioProgress: Double = 0
    var activeSamplesCount: Int {
        return Int(audioProgress * Double(normalizedSamples.count))
    }
    var isPlaying: Bool = false
    
    var audioPlaybackIndex: Int = 0
    var currentAudioPlayback: Playback {
        return audioPlayblackRates[audioPlaybackIndex]
    }
    var audioLengthSamples: AVAudioFramePosition = 0
    
    // -MARK: Private
    private let audioEngine: AudioEngine = AudioEngine()
    private var needsFileScheduled = true
    private var wasPlaying = false
    private var audioURL: URL
    private var normalizedSamples: [Float] = []
    private let logger = Logger(subsystem: "JSWaveform.AudioPlayerModel", category: "Model")
    
    private var audioFile: AVAudioFile? {
        do {
            return try AVAudioFile(forReading: audioURL)
        }
        catch {
            return nil
        }
    }
    
    private var audioSampleRate: Double = 0
    private var audioLengthSeconds: Double = 0
    
    private var seekFrame: AVAudioFramePosition = 0
    private var currentPosition: AVAudioFramePosition = 0
    private var currentFrame: AVAudioFramePosition = 0
    
    private let waveformLoader = AudioPlayerLoader()
    
    private let audioPlayblackRates: [Playback] = [
        .init(value: 1, label: "1x"),
        .init(value: 1.5, label: "1.5x"),
        .init(value: 2, label: "2x")
    ]
    
    init(audioURL url: URL) {
        audioURL = url
        super.init()
    }
    
    func loadSamples() async throws -> [Float] {
        return try await waveformLoader.loadSamples(forURL: audioURL)
    }
    
    func loadSamples(downsampledTo: Int) async throws -> [Float] {
        let samples = try await waveformLoader.loadSamples(forURL: audioURL, downsampledTo: downsampledTo)
        normalizedSamples = normalizeWaveformData(samples)
        return normalizedSamples
    }
    
    public func configureAudioEngine() {
        guard let audioFile else {
            return
        }
        
        let format = audioFile.processingFormat

        audioLengthSamples = audioFile.length
        audioSampleRate = format.sampleRate
        audioLengthSeconds = Double(audioLengthSamples) / audioSampleRate
        
        audioEngine.setup()
        audioEngine.start()
        scheduleAudioFile()
        logger.debug("Audio Engine started.")
    }
    
    func playOrPauseAudioPlayer() {
        if isPlaying {
            displayLink?.isPaused = true
            isPlaying = false
            audioEngine.pausePlayers()
            logger.debug("Audio is paused.")
        }
        else {
            displayLink?.isPaused = false
            if needsFileScheduled {
              scheduleAudioFile()
            }
            audioEngine.playPlayers()
            isPlaying = true
            logger.debug("Audio is playing.")
        }
    }
    
    func updateAudioPlayback() {
        var currentIndex = audioPlaybackIndex
        currentIndex += 1
        if currentIndex >= audioPlayblackRates.count {
            currentIndex = 0
        }
        audioPlaybackIndex = currentIndex
        let selectedRate = audioPlayblackRates[audioPlaybackIndex]
        Task {
            await audioEngine.setAudioTimePitchRate(rate: Float(selectedRate.value))
        }
    }
    
    func updateTimeWhileDrag(for position: Double) {
        let newPosition = Double(position) * Double(audioLengthSamples)
        let newTime = newPosition * audioLengthSeconds / Double(audioLengthSamples)
        audioTime = AudioTime(elapsedTime: newTime, audioLengthTime: audioLengthSeconds)
    }
    
    func seekBegin() {
        displayLink?.isPaused = true
        wasPlaying = true
        isPlaying = false
        audioEngine.stopPlayers()
    }
    
    func seekToPosition(_ position: Double) {
        let newPosition = Double(position) * Double(audioLengthSamples)
        let newTime = newPosition * audioLengthSeconds / Double(audioLengthSamples)
        
        // Update the seekFrame and currentPosition based on the new time
        let offset = AVAudioFramePosition(newTime * audioSampleRate)
        seekFrame = offset
        currentPosition = seekFrame
        
        // Stop the players, update the audio engine and schedule the new segment
        audioEngine.stopPlayers()
        
        if currentPosition < audioLengthSamples {
            needsFileScheduled = false
            let frameCount = AVAudioFrameCount(audioLengthSamples - seekFrame)
            
            Task {
                logger.debug("Scheduling a segment for audio \(self.audioFile!.url), seekFrame: \(self.seekFrame), frameCount: \(frameCount)")
                await audioEngine.scheduleSegment(audioFile!, startingFrame: currentPosition, frameCount: frameCount)
                await MainActor.run {
                    needsFileScheduled = true
                }
            }
            
            // If it was playing before, resume playback
            if wasPlaying {
                wasPlaying = false
                displayLink?.isPaused = false
                audioEngine.playPlayers()
                isPlaying = true
            }
        }
    }
    
    private func scheduleAudioFile() {
        guard let file = audioFile, needsFileScheduled else {
            return
        }

        needsFileScheduled = false
        seekFrame = 0
              
        Task(priority: .userInitiated) {
            await audioEngine.scheduleFile(file)
            await MainActor.run {
                needsFileScheduled = true
            }
        }
    }
    
    private func normalizeWaveformData(_ data: [Float]) -> [Float] {
        guard let maxSample = data.max() else { return [] }
        return data.map { $0 / maxSample }
    }
    
    // - MARK: Display link
    
    override func update() {
        Task {
            let currentFrame = await audioEngine.currentFrame()
            await MainActor.run {
                currentPosition = currentFrame + seekFrame
                currentPosition = max(currentPosition, 0)
                currentPosition = min(currentPosition, audioLengthSamples)

                if currentPosition >= audioLengthSamples {
                    audioEngine.stopPlayers()
                    seekFrame = 0
                    currentPosition = 0
                    
                    isPlaying = false
                    displayLink?.isPaused = true
                }

                audioProgress = Double(currentPosition) / Double(audioLengthSamples)

                let time = Double(currentPosition) / audioSampleRate
                audioTime = AudioTime(
                  elapsedTime: time,
                  audioLengthTime: audioLengthSeconds)
            }
        }
    }
}
