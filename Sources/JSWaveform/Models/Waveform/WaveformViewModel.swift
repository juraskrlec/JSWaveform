//
//  WaveformViewModel.swift
//
//
//  Created by Jura Skrlec on 23.06.2024..
//

import Foundation
import AVFoundation
import Observation

@Observable
class WaveformViewModel {
    
    // -MARK: Public
    var audioTime: AudioTime = .zero
    var audioProgress: Double = 0
    var isAudioPlayerPlaying: Bool {
        return audioEngine.isAudioPlayerPlaying
    }
    var activeSamplesCount: Int {
        return Int(audioProgress * Double(normalizedSamples.count))
    }
    var isPlaying: Bool = false
    var normalizedSamples: [Float] = []

    var audioURL: URL
    var audioPlaybackIndex: Int = 0
    var currentAudioPlayback: Playback {
        return audioPlayblackRates[audioPlaybackIndex]
    }
    
    // -MARK: Private
    private var audioEngine: AudioEngine!
    private var displayLink: CADisplayLink?
    private var needsFileScheduled = true
    private var wasPlaying = false
    
    private var audioFile: AVAudioFile? {
        do {
            return try AVAudioFile(forReading: audioURL)
        }
        catch {
            return nil
        }
    }
        
    var audioSampleRate: Double = 0
    var audioLengthSeconds: Double = 0
    
    private var seekFrame: AVAudioFramePosition = 0
    private var currentPosition: AVAudioFramePosition = 0
    var audioLengthSamples: AVAudioFramePosition = 0
    private var currentFrame: AVAudioFramePosition {
      guard
        let lastRenderTime = audioEngine.lastRenderTime,
        let playerTime = audioEngine.playerTime(forNodeTime: lastRenderTime)
      else {
        return 0
      }

      return playerTime.sampleTime
    }
    
    let audioPlayblackRates: [Playback] = [
      .init(value: 1, label: "1x"),
      .init(value: 1.5, label: "1.5x"),
      .init(value: 2, label: "2x")
    ]
        
    init(audioURL url: URL) {
        audioURL = url
        audioEngine = AudioEngine()
        setupAudio()
        setDisplayLink()
    }
    
    deinit {
        removeDisplayLink()
    }
    
    func waveformSamples(forURL url: URL) async throws -> [Float] {
        do {
            let samples = try await audioEngine.loadWaveform(from: url)
            return normalizeWaveformData(samples)
        }
        catch {
            throw error
        }
    }
    
    func waveformSamples(forURL url: URL, downsampledTo targetSampleCount: Int) async throws -> [Float] {
        do {
            let samples = try await audioEngine.loadWaveform(from: url, downsampledTo: targetSampleCount)
            normalizedSamples = normalizeWaveformData(samples)
            return normalizedSamples
        }
        catch {
            throw error
        }
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
    }
    
    func playAudioPlayer() {
        isPlaying = true
        if !isAudioPlayerPlaying {
            displayLink?.isPaused = false
            if needsFileScheduled {
              scheduleAudioFile()
            }
            audioEngine.playPlayers()
        }
    }
    
    func stopAudioPlayer() {
        isPlaying = false
        if isAudioPlayerPlaying {
            displayLink?.isPaused = true
            audioEngine.stopPlayers()
        }
    }
    
    func pauseAudioPlayer() {
        isPlaying = false
        if audioEngine.isAudioPlayerPlaying {
            displayLink?.isPaused = true
            audioEngine.pausePlayers()
        }
    }
    
    func playOrPauseAudioPlayer() {
        isPlaying.toggle()
        if isAudioPlayerPlaying {
            displayLink?.isPaused = true
            audioEngine.pausePlayers()
        }
        else {
            displayLink?.isPaused = false
            if needsFileScheduled {
              scheduleAudioFile()
            }
            audioEngine.playPlayers()
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
        audioEngine.setAudioTimePitchRate(rate: Float(selectedRate.value))
    }
    
    func seekBegin() {
        displayLink?.isPaused = true
        wasPlaying = true
        isPlaying = false
        audioEngine.pausePlayers()
    }
    
    func seekEnd(to time: Double) {
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
            audioEngine.seekAudio(audioFile: audioFile, startingFrame: seekFrame, frameCount: frameCount) {
                self.needsFileScheduled = true
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
      
        audioEngine.scheduleFile(file: file) {
            self.needsFileScheduled = true
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
