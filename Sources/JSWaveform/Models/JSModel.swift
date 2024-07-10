//
//  JSModel.swift
//
//
//  Created by Jura Skrlec on 10.07.2024.
//

import Foundation
import AVFoundation

@MainActor class JSModel {

    var displayLink: CADisplayLink?
    
    init() {
        setDisplayLink()
    }
    
    func clean() {
        removeDisplayLink()
    }
    
    func setDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(update))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: Float(JSScreen.maximumFramesPerSecond), __preferred: Float(JSScreen.maximumFramesPerSecond))
        displayLink?.add(to: .current, forMode: .common)
    }
    
    func removeDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc func update() {
        
    }
    
}
