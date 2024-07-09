//
//  AudioEngine.swift
//
//
//  Created by Jura Skrlec on 23.06.2024.
//

import AVFoundation
import Foundation
import Observation

actor AudioEngine {
    
    private let avAudioEngine = AVAudioEngine()
    private let audioPlayer = AVAudioPlayerNode()
    private let audioTimePitch = AVAudioUnitTimePitch()
    private var audioBuffer: AVAudioPCMBuffer?
    private var asyncBufferStream: AsyncStream<AVAudioPCMBuffer>?
    private var continuation: AsyncStream<AVAudioPCMBuffer>.Continuation?
    private var audioFormat: AVAudioFormat?
    
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
            print("Could not start audio engine: \(error)")
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
            guard let tempAudioBuffer = AudioEngine.getBuffer(fileURL: url) else { throw AudioEngineError.bufferRetrieveError }
            audioBuffer = tempAudioBuffer
            guard let audioBuffer = audioBuffer else { throw AudioEngineError.bufferRetrieveError }
            audioFormat = audioBuffer.format
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
        
    func seekAudio(audioFile: AVAudioFile, startingFrame: AVAudioFramePosition, frameCount: AVAudioFrameCount) async {
        await withCheckedContinuation { continuation in
            audioPlayer.scheduleSegment(audioFile, startingFrame: startingFrame, frameCount: frameCount, at: nil) {
                continuation.resume()
            }
        }
    }
    
    func scheduleFile(file: AVAudioFile) async {
        await withCheckedContinuation { continuation in
            audioPlayer.scheduleFile(file, at: nil) {
                continuation.resume()
            }
        }
    }
    
    func setAudioTimePitchRate(rate: Float) {
        audioTimePitch.rate = rate
    }
    
    func currentFrame() -> AVAudioFramePosition {
        guard let playerTime = playerTime(forNodeTime: audioPlayer.lastRenderTime) else { return 0 }
        return playerTime.sampleTime
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
    
    private func playerTime(forNodeTime nodeTime: AVAudioTime?) -> AVAudioTime? {
        guard let nodeTime else { return nil }
        return audioPlayer.playerTime(forNodeTime: nodeTime)
    }
}

