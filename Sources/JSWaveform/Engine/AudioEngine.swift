//
//  AudioEngine.swift
//
//
//  Created by Jura Skrlec on 23.06.2024.
//

import AVFoundation
import Foundation
import Observation

class AudioEngine {
    
    private var avAudioEngine = AVAudioEngine()
    private var audioPlayer = AVAudioPlayerNode()
    private var audioTimePitch = AVAudioUnitTimePitch()
    private var audioBuffer: AVAudioPCMBuffer?
    
    public private(set) var audioFormat: AVAudioFormat?
    public private(set) var audioProcessing = AudioProcessing()
    
    var lastRenderTime: AVAudioTime? {
        get {
            return audioPlayer.lastRenderTime
        }
    }
    
    var playerTime: AVAudioTime? {
        guard let lastRenderTime else {
            return nil
        }
        return audioPlayer.playerTime(forNodeTime: lastRenderTime)
    }
        
    func playerTime(forNodeTime nodeTime: AVAudioTime) -> AVAudioTime? {
        return audioPlayer.playerTime(forNodeTime: nodeTime)
    }
    
    enum AudioEngineError: Error {
        case bufferRetrieveError
        case fileFormatError
        case audioFileNotFound
    }
    
    init() {
        avAudioEngine.attach(audioPlayer)
        avAudioEngine.attach(audioTimePitch)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(configChanged(_:)),
                                               name: .AVAudioEngineConfigurationChange,
                                               object: avAudioEngine)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc
    func configChanged(_ notification: Notification) {
        checkEngineIsRunning()
    }

    private static func getBuffer(fileURL: URL) -> AVAudioPCMBuffer? {
        let file: AVAudioFile!
        do {
            try file = AVAudioFile(forReading: fileURL)
        } catch {
            print("Could not load file: \(error)")
            return nil
        }
        file.framePosition = 0
        
        // Add 100 ms to the capacity.
        let bufferCapacity = AVAudioFrameCount(file.length)
                + AVAudioFrameCount(file.processingFormat.sampleRate * 0.1)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                            frameCapacity: bufferCapacity) else { return nil }
        do {
            try file.read(into: buffer)
        } catch {
            print("Could not load file into buffer: \(error)")
            return nil
        }
        file.framePosition = 0
        return buffer
    }

    func setup() {
        let input = avAudioEngine.inputNode
        do {
            try input.setVoiceProcessingEnabled(true)
        } catch {
            print("Could not enable voice processing \(error)")
            return
        }

        let output = avAudioEngine.outputNode
        let mainMixer = avAudioEngine.mainMixerNode

        avAudioEngine.connect(audioPlayer, to: audioTimePitch, format:nil)
        avAudioEngine.connect(audioTimePitch, to: mainMixer, format: nil)
        avAudioEngine.connect(mainMixer, to: output, format: nil)

        audioPlayer.installTap(onBus: 0, bufferSize: 256, format: nil) { buffer, _ in
            if self.audioPlayer.isPlaying {
                self.audioProcessing.process(buffer: buffer)
            } else {
                self.audioProcessing.processSilence()
            }
        }

        avAudioEngine.prepare()
    }

    func start() {
        do {
            try avAudioEngine.start()
        } catch {
            print("Could not start audio engine: \(error)")
        }
    }

    func checkEngineIsRunning() {
        if !avAudioEngine.isRunning {
            start()
        }
    }
    
    /// Use this when you need to use buffers, as when you animate amplitude or power
    /// Else, use play() instead, when scheduling a audio file
    func audioPlayerPlay(_ shouldPlay: Bool) {
        if shouldPlay {
            guard let audioBuffer = audioBuffer else { return }
            audioPlayer.scheduleBuffer(audioBuffer, at: nil, options: .loops)
            audioPlayer.play()
        } else {
            audioPlayer.stop()
        }
    }

    func setAudio(forURL url: URL, qos: DispatchQoS.QoSClass = .userInitiated) async throws {
        try await Task(priority: taskPriority(qos: qos)) {
            guard let tempAudioBuffer = AudioEngine.getBuffer(fileURL: url) else { throw AudioEngineError.bufferRetrieveError }
            audioBuffer = tempAudioBuffer
            guard let audioBuffer = audioBuffer else { throw AudioEngineError.bufferRetrieveError }
            audioFormat = audioBuffer.format
        }.value
    }

    func stopPlayers() {
        audioPlayer.stop()
    }
    
    func pausePlayers() {
        audioPlayer.pause()
    }
    
    func playPlayers() {
        audioPlayer.play()
    }

    var isAudioPlayerPlaying: Bool {
        return audioPlayer.isPlaying
    }
    
    typealias CompletionHandler = () -> Void
    
    func seekAudio(audioFile: AVAudioFile, startingFrame: AVAudioFramePosition, frameCount: AVAudioFrameCount, completion: @escaping CompletionHandler) {
        audioPlayer.scheduleSegment(audioFile, startingFrame: startingFrame, frameCount: frameCount, at: nil) {
            completion()
        }
    }
    
    func scheduleFile(file: AVAudioFile, completion: @escaping CompletionHandler) {
        audioPlayer.scheduleFile(file, at: nil) {
            completion()
        }
    }
    
    func setAudioTimePitchRate(rate: Float) {
        audioTimePitch.rate = rate
    }
    
    func loadWaveform(from audioURL: URL, qos: DispatchQoS.QoSClass = .userInitiated) async throws -> [Float] {
        try await Task(priority: taskPriority(qos: qos)) {
            let file = try? AVAudioFile(forReading: audioURL)
            guard let format = file?.processingFormat, let length = file?.length else { throw AudioEngineError.audioFileNotFound }
            
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(length))
            try? file?.read(into: buffer!)
            
            guard let floatChannelData = buffer?.floatChannelData else { throw AudioEngineError.bufferRetrieveError }
            let channelData = floatChannelData.pointee
            
            let samples = stride(from: 0, to: Int(length), by: Int(format.channelCount)).map { channelData[$0] }
            return samples
        }.value
    }
    
    func loadWaveform(from audioURL: URL, downsampledTo targetSampleCount: Int, qos: DispatchQoS.QoSClass = .userInitiated) async throws -> [Float] {
        try await Task(priority: taskPriority(qos: qos)) {
            let file = try? AVAudioFile(forReading: audioURL)
            guard let format = file?.processingFormat, let length = file?.length else { throw AudioEngineError.audioFileNotFound }
            
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(length))
            try? file?.read(into: buffer!)
            
            guard let floatChannelData = buffer?.floatChannelData else { throw AudioEngineError.bufferRetrieveError }
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
        }.value
    }
    
    private func taskPriority(qos: DispatchQoS.QoSClass) -> TaskPriority {
        switch qos {
        case .background:
            return .background
        case .utility:
            return .utility
        case .default:
            return .medium
        case .userInitiated:
            return .userInitiated
        case .userInteractive:
            return .high
        case .unspecified:
            return .medium
        @unknown default:
            return .medium
        }
    }
}

