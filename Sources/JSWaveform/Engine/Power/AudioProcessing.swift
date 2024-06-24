//
//  AudioProcessing.swift
//
//
//  Created by Jura Skrlec on 23.06.2024.
//

import Foundation
import AVFoundation
import Accelerate

class AudioProcessing: AudioLevelProvider {
    
    private let kMinLevel: Float = 0.000_000_01 // -160 dB
    
    private struct PowerLevels {
        let average: Float
        let peak: Float
    }
    
    private var values = [PowerLevels]()
    
    private var lookupTableAvarage = AudioLookup()
    private var lookupTablePeak = AudioLookup()

    var levels: AudioLevels {
        if values.isEmpty { return AudioLevels(level: 0.0, peakLevel: 0.0) }
        return AudioLevels(level: lookupTableAvarage.valueForPower(values[0].average),
                           peakLevel: lookupTablePeak.valueForPower(values[0].peak))
    }
    
    func processSilence() {
        if values.isEmpty { return }
        values = []
    }
    
    func process(buffer: AVAudioPCMBuffer) {
        var powerLevels = [PowerLevels]()
        let channelCount = Int(buffer.format.channelCount)
        let length = vDSP_Length(buffer.frameLength)

        if let floatData = buffer.floatChannelData {
            for channel in 0..<channelCount {
                powerLevels.append(calculatePowers(data: floatData[channel], strideFrames: buffer.stride, length: length))
            }
        } else if let int16Data = buffer.int16ChannelData {
            for channel in 0..<channelCount {
                var floatChannelData: [Float] = Array(repeating: Float(0.0), count: Int(buffer.frameLength))
                vDSP_vflt16(int16Data[channel], buffer.stride, &floatChannelData, buffer.stride, length)
                var scalar = Float(INT16_MAX)
                vDSP_vsdiv(floatChannelData, buffer.stride, &scalar, &floatChannelData, buffer.stride, length)

                powerLevels.append(calculatePowers(data: floatChannelData, strideFrames: buffer.stride, length: length))
            }
        } else if let int32Data = buffer.int32ChannelData {
            for channel in 0..<channelCount {
                var floatChannelData: [Float] = Array(repeating: Float(0.0), count: Int(buffer.frameLength))
                vDSP_vflt32(int32Data[channel], buffer.stride, &floatChannelData, buffer.stride, length)
                var scalar = Float(INT32_MAX)
                vDSP_vsdiv(floatChannelData, buffer.stride, &scalar, &floatChannelData, buffer.stride, length)

                powerLevels.append(calculatePowers(data: floatChannelData, strideFrames: buffer.stride, length: length))
            }
        }
        self.values = powerLevels
    }
    
    private func calculatePowers(data: UnsafePointer<Float>, strideFrames: Int, length: vDSP_Length) -> PowerLevels {
        var max: Float = 0.0
        vDSP_maxv(data, strideFrames, &max, length)
        if max < kMinLevel {
            max = kMinLevel
        }

        var rms: Float = 0.0
        vDSP_rmsqv(data, strideFrames, &rms, length)
        if rms < kMinLevel {
            rms = kMinLevel
        }

        return PowerLevels(average: 20.0 * log10(rms), peak: 20.0 * log10(max))
    }
}
