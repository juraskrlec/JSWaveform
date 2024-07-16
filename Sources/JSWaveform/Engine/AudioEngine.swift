//
//  AudioEngine.swift
//
//
//  Created by Jura Skrlec on 23.06.2024.
//

import AVFoundation
import Foundation
import os

actor AudioEngine {
    
    private let avAudioEngine = AVAudioEngine()
    private let audioPlayer = AVAudioPlayerNode()
    private let audioTimePitch = AVAudioUnitTimePitch()
    private var audioBuffer: AVAudioPCMBuffer?
    private var asyncBufferStream: AsyncStream<AVAudioPCMBuffer>?
    private var continuation: AsyncStream<AVAudioPCMBuffer>.Continuation?
    
    private let logger = Logger(subsystem: "JSWaveform.AudioEngine", category: "Engine")
    
    enum AudioEngineError: Error {
        case bufferRetrieveError
    }
    
    init() {
        avAudioEngine.attach(audioPlayer)
        avAudioEngine.attach(audioTimePitch)
    }

    nonisolated func setup() {
        let output = avAudioEngine.outputNode
        let mainMixer = avAudioEngine.mainMixerNode

        avAudioEngine.connect(audioPlayer, to: audioTimePitch, format:nil)
        avAudioEngine.connect(audioTimePitch, to: mainMixer, format: nil)
        avAudioEngine.connect(mainMixer, to: output, format: nil)
        avAudioEngine.prepare()
    }
    
    func prepareBuffer() {
        asyncBufferStream = AsyncStream { continuation in
             self.continuation = continuation
         }
        
        audioPlayer.installTap(onBus: 0, bufferSize: 256, format: nil) { buffer, _ in
            self.continuation?.yield(buffer)
        }
    }
    
    func getBuffer() -> AsyncStream<AVAudioPCMBuffer>? {
        return asyncBufferStream
    }

    nonisolated func start() {
        do {
            try avAudioEngine.start()
        } catch {
            logger.error("Could not start audio engine: \(error)")
        }
    }

    func checkEngineIsRunning() {
        if !avAudioEngine.isRunning {
            start()
        }
    }
    
    func scheduleBuffer(priority: TaskPriority = .userInitiated) async {
        Task(priority: priority) {
            guard let audioBuffer = audioBuffer else { return }
            await audioPlayer.scheduleBuffer(audioBuffer, at: nil, options: .interrupts)
        }
    }

    func setBuffer(forURL url: URL, priority: TaskPriority = .userInitiated) async throws {
        try await Task(priority: priority) {
            guard let tempAudioBuffer = getBuffer(fileURL: url) else { throw AudioEngineError.bufferRetrieveError }
            audioBuffer = tempAudioBuffer
        }.value
    }

    nonisolated func stopPlayers() {
        audioPlayer.stop()
    }
    
    nonisolated func pausePlayers() {
        audioPlayer.pause()
    }
    
    nonisolated func playPlayers() {
        audioPlayer.play()
    }
        
    func scheduleSegment(_ file: AVAudioFile, startingFrame: AVAudioFramePosition, frameCount: AVAudioFrameCount) async {
        await audioPlayer.scheduleSegment(file, startingFrame: startingFrame, frameCount: frameCount, at: nil)
    }
    
    func scheduleFile(_ file: AVAudioFile) async {
        await audioPlayer.scheduleFile(file, at: nil)
    }
    
    func setAudioTimePitchRate(rate: Float) {
        audioTimePitch.rate = rate
    }
    
    func currentFrame() -> AVAudioFramePosition {
        guard let playerTime = playerTime(forNodeTime: audioPlayer.lastRenderTime) else { return 0 }
        return playerTime.sampleTime
    }
    
    private func getBuffer(fileURL: URL) -> AVAudioPCMBuffer? {
        let file: AVAudioFile!
        do {
            try file = AVAudioFile(forReading: fileURL)
        } catch {
            logger.error("Could not load file: \(error)")
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
            logger.error("Could not load file into buffer: \(error)")
            return nil
        }
        file.framePosition = 0
        return buffer
    }
    
    private func playerTime(forNodeTime nodeTime: AVAudioTime?) -> AVAudioTime? {
        guard let nodeTime else { return nil }
        return audioPlayer.playerTime(forNodeTime: nodeTime)
    }
}

