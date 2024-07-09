//
//  WaveformViewModel.swift
//
//
//  Created by Jura Skrlec on 23.06.2024..
//

import Foundation
import AVFoundation
import Observation
import os

private actor WaveformLoader {
    let logger = Logger(subsystem: "JSWaveform.WafeformLoader", category: "ModelIO")
    
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
@MainActor class WaveformViewModel {
    
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
    private var displayLink: CADisplayLink?
    private var needsFileScheduled = true
    private var wasPlaying = false
    private var audioURL: URL
    private var normalizedSamples: [Float] = []
    private let logger = Logger(subsystem: "JSWaveform.WafeformViewModel", category: "ViewModel")
    
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
    
    private let waveformLoader = WaveformLoader()
    
    private let audioPlayblackRates: [Playback] = [
        .init(value: 1, label: "1x"),
        .init(value: 1.5, label: "1.5x"),
        .init(value: 2, label: "2x")
    ]
    
    init(audioURL url: URL) {
        audioURL = url
        setupAudio()
        setDisplayLink()
    }
    
    func clean() {
        removeDisplayLink()
    }
    
    func loadSamples() async throws -> [Float] {
        return try await waveformLoader.loadSamples(forURL: audioURL)
    }
    
    func loadSamples(downsampledTo: Int) async throws -> [Float] {
        let samples = try await waveformLoader.loadSamples(forURL: audioURL, downsampledTo: downsampledTo)
        normalizedSamples = normalizeWaveformData(samples)
        return normalizedSamples
    }
    
    func setupAudio() {
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
            logger.debug("Audio paused.")
        }
        else {
            displayLink?.isPaused = false
            isPlaying = true
            if needsFileScheduled {
              scheduleAudioFile()
            }
            audioEngine.playPlayers()
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
    
    func seekBegin() {
        displayLink?.isPaused = true
        wasPlaying = true
        isPlaying = false
        audioEngine.pausePlayers()
    }
    
    func updateTime(for position: Double) {
        let newPosition = Double(position) * Double(audioLengthSamples)
        let newTime = newPosition * audioLengthSeconds / Double(audioLengthSamples)
        let doubleDownTime = floor(newTime)
        let time: Double
        if doubleDownTime.isZero {
            time = -audioTime.elapsedTime
        }
        else if doubleDownTime.isLessThanOrEqualTo(audioTime.elapsedTime) {
            time = -(audioTime.elapsedTime - doubleDownTime)
        }
        else {
            time = doubleDownTime - audioTime.elapsedTime
        }
        seekEnd(to: time)
    }
    
    private func seekEnd(to time: Double) {
        guard let audioFile = audioFile else {
            return
        }
        
        let offset = AVAudioFramePosition(time * audioSampleRate)
        seekFrame = currentPosition + offset
        seekFrame = max(seekFrame, 0)
        seekFrame = min(seekFrame, audioLengthSamples)
        currentPosition = seekFrame
        
        audioEngine.stopPlayers()
        
        if currentPosition < audioLengthSamples {
            update()
            needsFileScheduled = false

            let frameCount = AVAudioFrameCount(audioLengthSamples - seekFrame)
            Task {
                await audioEngine.seekAudio(audioFile: audioFile, startingFrame: seekFrame, frameCount: frameCount)
                needsFileScheduled = true
            }

            if wasPlaying {
                wasPlaying.toggle()
                isPlaying = true
                displayLink?.isPaused = false
                audioEngine.playPlayers()
            }
            
        }
    }
    
    private func scheduleAudioFile() {
        guard let file = audioFile, needsFileScheduled else {
            return
        }

        needsFileScheduled = false
        seekFrame = 0
      
        Task {
            await audioEngine.scheduleFile(file: file)
            needsFileScheduled = true
        }
    }
    
    private func normalizeWaveformData(_ data: [Float]) -> [Float] {
        guard let maxSample = data.max() else { return [] }
        return data.map { $0 / maxSample }
    }
    
    // - MARK: Display link
    fileprivate func setDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(update))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: Float(JSScreen.maximumFramesPerSecond), __preferred: Float(JSScreen.maximumFramesPerSecond))
        displayLink?.add(to: .current, forMode: .default)
        displayLink?.isPaused = true
    }
    
    fileprivate func removeDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func update() {
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
