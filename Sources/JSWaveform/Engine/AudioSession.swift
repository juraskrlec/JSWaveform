//
//  AudioSession.swift
//
//
//  Created by Jura Skrlec on 23.06.2024.
//

#if os(iOS)
import Foundation
import AVFoundation

protocol AudioSessionDelegate: AnyObject {
    func didInterruptionBegin(forAudioSession audioSession: AudioSession)
    func mediaServicesWereReset(forAudioSession audioSession: AudioSession)
}

class AudioSession {
    
    weak var delegate: AudioSessionDelegate?
    
    init() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.handleInterruption(_:)),
                                               name: AVAudioSession.interruptionNotification,
                                               object: AVAudioSession.sharedInstance())
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.handleRouteChange(_:)),
                                               name: AVAudioSession.routeChangeNotification,
                                               object: AVAudioSession.sharedInstance())
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.handleMediaServicesWereReset(_:)),
                                               name: AVAudioSession.mediaServicesWereResetNotification,
                                               object: AVAudioSession.sharedInstance())
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func setupAudioSession(sampleRate: Double) {
        let session = AVAudioSession.sharedInstance()

        do {
            try session.setCategory(.playAndRecord, options: .defaultToSpeaker)
        } catch {
            print("Could not set the audio category: \(error.localizedDescription)")
        }

        do {
            try session.setPreferredSampleRate(sampleRate)
        } catch {
            print("Could not set the preferred sample rate: \(error.localizedDescription)")
        }
    }
}

// - MARK: Handle notifications
extension AudioSession {
    
    @objc
    func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        
        switch type {
        case .began:
            self.delegate?.didInterruptionBegin(forAudioSession: self)
        case .ended:
            do {
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("Could not set the audio session to active: \(error)")
            }
            
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    // Interruption ends. Resume playback.
                } else {
                    // Interruption ends. Don't resume playback.
                }
            }
        @unknown default:
            fatalError("Unknown type: \(type)")
        }
    }
    
    @objc
    func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue),
            let routeDescription = userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription else { return }
        switch reason {
        case .newDeviceAvailable:
            print("newDeviceAvailable")
        case .oldDeviceUnavailable:
            print("oldDeviceUnavailable")
        case .categoryChange:
            print("categoryChange")
            print("New category: \(AVAudioSession.sharedInstance().category)")
        case .override:
            print("override")
        case .wakeFromSleep:
            print("wakeFromSleep")
        case .noSuitableRouteForCategory:
            print("noSuitableRouteForCategory")
        case .routeConfigurationChange:
            print("routeConfigurationChange")
        case .unknown:
            print("unknown")
        @unknown default:
            fatalError("Really unknown reason: \(reason)")
        }
        
        print("Previous route:\n\(routeDescription)")
        print("Current route:\n\(AVAudioSession.sharedInstance().currentRoute)")
    }
    
    @objc
    func handleMediaServicesWereReset(_ notification: Notification) {
        self.delegate?.mediaServicesWereReset(forAudioSession: self)
    }
    
}
#endif
