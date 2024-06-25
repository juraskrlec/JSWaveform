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
    var maxNumberOfAmplitudes: Int
    var animationType: AudioVisualizer.AnimationType
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
    
    private let audioSession = AudioSession()
    
    init(audioURL url: URL, maxNumberOfAmplitudes: Int, animationType: AudioVisualizer.AnimationType) {
        audioEngine = AudioEngine()
        audioURL = url
        self.maxNumberOfAmplitudes = maxNumberOfAmplitudes
        self.animationType = animationType
        audioLevel.levelProvider = audioEngine.audioProcessing
        setDisplayLink()
//        audioSession.delegate = self
        amplitudes = [Double](repeating: 0.0, count: maxNumberOfAmplitudes)
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
    
    func setAudioEngine(forURL url: URL, priority: TaskPriority = .userInitiated) async throws {
        do {
            try await audioEngine.setAudio(forURL: url, priority: priority)
            
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
            let equalValue = Double(peakLevel)
            targetAmplitudes = Array(repeating: equalValue, count: amplitudes.count)
            break
        case .lowToHigh:
            targetAmplitudes = (0..<amplitudes.count).map { index in
                let normalizedIndex = Double(index) / Double(amplitudes.count - 1)
                let scalingFactor = 1.0 + normalizedIndex * 1.5
                let amplitude = level * (1.0 - normalizedIndex) + peakLevel * normalizedIndex
                return min(1.0, max(0.0, pow(amplitude * scalingFactor, 1.2)))
            }
            break
        case .highToLow:
            targetAmplitudes = (0..<amplitudes.count).map { index in
                let normalizedIndex = Double(index) / Double(amplitudes.count - 1)
                let scalingFactor = 1.0 + (1.0 - normalizedIndex) * 1.5
                let amplitude = level * (1.0 - normalizedIndex) + peakLevel * normalizedIndex
                return min(1.0, max(0.0, pow(amplitude * scalingFactor, 1.2)))
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
            var shuffledAmplitudes = (0..<amplitudes.count).map { index in
                let normalizedIndex = Double(index) / Double(amplitudes.count - 1)
                let scalingFactor = 1.0 + normalizedIndex * 1.5
                let amplitude = level * (1.0 - normalizedIndex) + peakLevel * normalizedIndex
                return min(1.0, max(0.0, pow(amplitude * scalingFactor, 1.2)))
            }
            shuffledAmplitudes.shuffle()
            targetAmplitudes = shuffledAmplitudes
            break
        case .bounce:
            targetAmplitudes = (0..<amplitudes.count).map { index in
                let bounceValue = abs(sin(Double(index) + Date().timeIntervalSince1970 * 2)) * Double(peakLevel)
                return min(1.0, max(0.0, bounceValue))
            }
            break
        case .spiral:
            targetAmplitudes = (0..<amplitudes.count).map { index in
                let scale = 4 * .pi + Date().timeIntervalSince1970
                let spiralValue = (sin(Double(index) / Double(amplitudes.count - 1) * scale ) + 1) / 2 * Double(peakLevel)
                return min(1.0, max(0.0, spiralValue))
            }
        case .heartbeat:
            targetAmplitudes = (0..<amplitudes.count).map { index in
                let heartbeatValue = pow(sin(Double(index) / Double(amplitudes.count - 1) * 2 * .pi + Date().timeIntervalSince1970 * 4), 2) * Double(peakLevel)
                return min(1.0, max(0.0, heartbeatValue))
            }
        case .randomPeaks:
            targetAmplitudes = (0..<amplitudes.count).map { _ in
                let randomPeakValue = (0..<amplitudes.count).map { _ in Double.random(in: 0...Double(peakLevel)) }.max()!
                return min(1.0, max(0.0, randomPeakValue))
            }
        case .oscillation:
            let scale = 4 * .pi + Date().timeIntervalSince1970
            targetAmplitudes = (0..<amplitudes.count).map { index in
                let oscillationValue = (sin(Double(index) / Double(amplitudes.count - 1) * scale) + 1) / 2 * Double(peakLevel)
                return min(1.0, max(0.0, oscillationValue))
            }
        case .risingAndFallingPeaks:
            let halfCount = amplitudes.count / 2
            let risingAmplitudes = (0..<halfCount).map { index in
                let normalizedIndex = Double(index) / Double(halfCount - 1)
                let amplitude = normalizedIndex * Double(peakLevel)
                return min(1.0, max(0.0, amplitude))
            }
            targetAmplitudes = risingAmplitudes + risingAmplitudes.reversed()
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
