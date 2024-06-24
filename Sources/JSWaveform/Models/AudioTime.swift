//
//  AudioTime.swift
//
//
//  Created by Jura Skrlec on 23.06.2024.
//

import Foundation

struct AudioTime {
    let elapsedTime: Double
    let audioLengthTime: Double
    let elapsedText: String
    let audioLengthText: String
    
    enum TimeConstant {
      static let secsPerMin = 60
      static let secsPerHour = TimeConstant.secsPerMin * 60
    }
    
    static let zero: AudioTime = .init(elapsedTime: 0, audioLengthTime: 0)
    
    init(elapsedTime: Double, audioLengthTime: Double) {
        self.elapsedTime = elapsedTime
        self.audioLengthTime = audioLengthTime
        self.elapsedText = AudioTime.formatted(time: elapsedTime)
        self.audioLengthText = AudioTime.formatted(time: audioLengthTime)
    }
    
    private static func formatted(time: Double) -> String {
      var seconds = Int(ceil(time))
      var hours = 0
      var mins = 0

      if seconds > TimeConstant.secsPerHour {
        hours = seconds / TimeConstant.secsPerHour
        seconds -= hours * TimeConstant.secsPerHour
      }

      if seconds > TimeConstant.secsPerMin {
        mins = seconds / TimeConstant.secsPerMin
        seconds -= mins * TimeConstant.secsPerMin
      }

      var formattedString = ""
      if hours > 0 {
        formattedString = "\(String(format: "%02d", hours)):"
      }
      formattedString += "\(String(format: "%02d", mins)):\(String(format: "%02d", seconds))"
      return formattedString
    }
}

