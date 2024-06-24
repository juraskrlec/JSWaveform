//
//  Utils.swift
//
//
//  Created by Jura Skrlec on 23.06.2024..
//

import Foundation
import SwiftUI
import UIKit

public enum JSScreen {
    public static var maximumFramesPerSecond: Int {
        return UIScreen.main.maximumFramesPerSecond
    }
}

public extension Image {
    static let play = Image(systemName: "play.fill")
    static let pause = Image(systemName: "pause.fill")
}
