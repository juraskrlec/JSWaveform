//
//  AudioVisualizerViewModel.swift
//
//
//  Created by Jura Skrlec on 23.06.2024.
//

import Foundation
import AVFoundation
import Observation

public enum AudioVisualizerAnimationType {
    case equal
    case lowToHigh
    case highToLow
    case symetricMiddleHigh
    case symetricMiddleLow
    case shuffle
}

@Observable
class AudioVisualizerViewModel {
    
    // - MARK: Public
    var amplitudes: [Double] = []
    var maximumRectangles = 10
    var animationType: AudioVisualizerAnimationType = .symetricMiddleHigh
    var isAudioPlayerPlaying: Bool {
        return audioEngine.isAudioPlayerPlaying
    }
    var audioURL: URL
    
    // - MARK: Private
    private var displayLink: CADisplayLink?
    private var audioEngine: AudioEngine!
    private var level: CGFloat = 0
    private var peakLevel: CGFloat = 0
    private var audioLevel = AudioLevel()
    
    private var audioFile: AVAudioFile? {
        do {
            return try AVAudioFile(forReading: audioURL)
        }
        catch {
            return nil
        }
    }
    
    #if os(iOS) || os(visionOS)
    private let audioSession = AudioSession()
    #endif
    
    init(audioURL url: URL) {
        audioEngine = AudioEngine()
        audioURL = url
        audioLevel.levelProvider = audioEngine.audioProcessing
        setDisplayLink()
//        audioSession.delegate = self
        amplitudes = [Double](repeating: 0.0, count: maximumRectangles)
    }
    
    deinit {
        removeDisplayLink()
    }
    
    func playAudioPlayer() {
        if !audioEngine.isAudioPlayerPlaying {
            displayLink?.isPaused = false
            audioEngine.audioPlayerPlay(true)
        }
    }
    
    func stopAudioPlayer() {
        if audioEngine.isAudioPlayerPlaying {
            displayLink?.isPaused = true
            audioEngine.audioPlayerPlay(false)
            stopAudioAnimation()
        }
    }
    
    func setAudioEngine(forURL url: URL) async throws {
        do {
            try await audioEngine.setAudio(forURL: url)
            
            guard let _ = audioEngine.audioFormat else { return }
//            audioSession.setupAudioSession(sampleRate: audioFormat.sampleRate)

            audioEngine.setup()
            audioEngine.start()
        }
        catch {
            throw error
        }
    }
    
    // MARK: Display updates

    private func setDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateWave))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: Float(JSScreen.maximumFramesPerSecond), __preferred: Float(JSScreen.maximumFramesPerSecond))
        displayLink?.add(to: .current, forMode: .common)
    }
    
    private func removeDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func updateWave() {
        
        guard let levels = audioLevel.levelProvider?.levels else {
            return
        }
        
        level = CGFloat(levels.level)
        peakLevel = CGFloat(levels.peakLevel)
        
        var targetAmplitudes:[Double]
        
        switch animationType {
        case .equal:
            targetAmplitudes = (0..<amplitudes.count).map { index in
                let normalizedIndex = Double(index) / Double(amplitudes.count - 1)
                let scalingFactor = 1.0 + normalizedIndex * 1.5
                let amplitude = level * (1.0 - normalizedIndex) + peakLevel * normalizedIndex
                let scaledAmplitude = min(1.0, max(0.0, pow(amplitude * scalingFactor, 1.2)))
                return scaledAmplitude
            }
            break
        case .lowToHigh:
            targetAmplitudes = (0..<amplitudes.count).map { index in
                let normalizedIndex = Double(index) / Double(amplitudes.count - 1)
                let scalingFactor = 1.0 + normalizedIndex * 1.5
                let amplitude = level * (1.0 - normalizedIndex) + peakLevel * normalizedIndex
                let scaledAmplitude = min(1.0, max(0.0, pow(amplitude * scalingFactor, 1.2)))
                return scaledAmplitude
            }
            break
        case .highToLow:
            targetAmplitudes = (0..<amplitudes.count).map { index in
                let normalizedIndex = Double(index) / Double(amplitudes.count - 1)
                let scalingFactor = 1.0 + normalizedIndex * 1.5
                let amplitude = level * (1.0 - normalizedIndex) + peakLevel * normalizedIndex
                let scaledAmplitude = min(1.0, max(0.0, pow(amplitude * scalingFactor, 1.2)))
                return scaledAmplitude
            }
            break
        case .symetricMiddleHigh:
            let halfCount = amplitudes.count / 2
            let newAmplitudes = (0..<halfCount).map { index in
                let normalizedIndex = Double(index) / Double(halfCount - 1)
                let scalingFactor = 1.0 + normalizedIndex * 1.5
                let amplitude = level * (1.0 - normalizedIndex) + peakLevel * normalizedIndex
                return min(1.0, max(0.0, pow(amplitude * scalingFactor, 1.2)))
            }
            targetAmplitudes = newAmplitudes + newAmplitudes.reversed()
            break
        case .symetricMiddleLow:
            let halfCount = amplitudes.count / 2
            let newAmplitudes = (0..<halfCount).map { index in
                let normalizedIndex = Double(index) / Double(halfCount - 1)
                let scalingFactor = 1.0 + (1.0 - normalizedIndex) * 1.5
                let amplitude = level * (1.0 - normalizedIndex) + peakLevel * normalizedIndex
                return min(1.0, max(0.0, pow(amplitude * scalingFactor, 1.2)))
            }
            
            targetAmplitudes = newAmplitudes + newAmplitudes.reversed()
            break
        case .shuffle:
            targetAmplitudes = (0..<amplitudes.count).map { index in
                let normalizedIndex = Double(index) / Double(amplitudes.count - 1)
                let scalingFactor = 1.0 + normalizedIndex * 1.5
                let amplitude = level * (1.0 - normalizedIndex) + peakLevel * normalizedIndex
                return min(1.0, max(0.0, pow(amplitude * scalingFactor, 1.2)))
            }
    
            targetAmplitudes.shuffle()
            break
        }
        
        if peakLevel > 0 {
            self.amplitudes = self.amplitudes.enumerated().map { index, current in
                self.lowPassFilter(currentValue: current, targetValue: targetAmplitudes[index])
            }
        }
    }
    
    private func lowPassFilter(currentValue: Double, targetValue: Double, smoothing: Double = 0.1) -> Double {
        return currentValue * (1.0 - smoothing) + targetValue * smoothing
    }
    
    func reset() {
        level = 0
        peakLevel = 0
    }
    
    // - MARK: Animations
    func stopAudioAnimation() {
        amplitudes = [Double](repeating: 0.0, count: 10)
    }

}

// - MARK: Delegate
extension AudioVisualizerViewModel: AudioSessionDelegate {
    
    func didInterruptionBegin(forAudioSession audioSession: AudioSession) {
        audioEngine.stopPlayers()
    }
    
    func mediaServicesWereReset(forAudioSession audioSession: AudioSession) {
        resetAudioEngine()
    }
    
    func resetAudioEngine() {
        audioEngine = nil
        audioEngine = AudioEngine()
    }
}
