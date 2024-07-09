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
}

@Observable
@MainActor class AudioVisualizerViewModel {
    
    // - MARK: Public
    var amplitudes: [Double] = []
    var maxNumberOfAmplitudes: Int
    var audioURL: URL
    var isPlaying: Bool = false
    
    // - MARK: Private
    private var displayLink: CADisplayLink?
    private let audioEngine: AudioEngine = AudioEngine()
    private let audioProcessing = AudioProcessing()
    private var level: CGFloat = 0
    private var peakLevel: CGFloat = 0
    private let audioLevel = AudioLevel()
    private var animationType: AudioVisualizer.AnimationType

    private var audioFile: AVAudioFile? {
        do {
            return try AVAudioFile(forReading: audioURL)
        }
        catch {
            return nil
        }
    }
        
    init(audioURL url: URL, maxNumberOfAmplitudes: Int, animationType: AudioVisualizer.AnimationType) {
        audioURL = url
        self.maxNumberOfAmplitudes = maxNumberOfAmplitudes
        self.animationType = animationType
        audioLevel.levelProvider = audioProcessing
        setDisplayLink()
        amplitudes = [Double](repeating: 0.0, count: maxNumberOfAmplitudes)
    }
    
    func clean() {
        removeDisplayLink()
    }
    
    func playAudioPlayer() {
        if !isPlaying {
            isPlaying = true
            displayLink?.isPaused = false
            Task {
                await audioEngine.scheduleBuffer()
                audioEngine.playPlayers()
            }

        }
    }
    
    func stopAudioPlayer() {
        if isPlaying {
            isPlaying = false
            displayLink?.isPaused = true
            audioEngine.stopPlayers()
            stopAudioAnimation()
        }
    }
    
    func pauseAudioPlayer() {
        if isPlaying {
            isPlaying = false
            displayLink?.isPaused = true
            audioEngine.pausePlayers()
            stopAudioAnimation()
        }
    }
    
    func prepareAudioEngine(priority: TaskPriority = .userInitiated) async throws {
            try await audioEngine.setBuffer(forURL: audioURL, priority: priority)
            
            audioEngine.setup()
            await audioEngine.prepareBuffer()
            audioEngine.start()
    }
    
    public func processAudio() async {
         guard let bufferStream = await audioEngine.getBuffer() else { return }

         for await buffer in bufferStream {
             if isPlaying {
                 audioProcessing.process(buffer: buffer)
             } else {
                 audioProcessing.processSilence()
             }
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
        amplitudes = [Double](repeating: 0.0, count: maxNumberOfAmplitudes)
    }

}
