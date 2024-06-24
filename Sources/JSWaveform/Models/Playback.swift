//
//  Playback.swift
//
//
//  Created by Jura Skrlec on 23.06.2024.
//

import Foundation

struct Playback: Identifiable {
  let value: Double
  let label: String

  var id: String {
    return "\(label)-\(value)"
  }
}
