//
//  UIDevice+Vibration.swift
//  DeltaCore
//
//  Created by Riley Testut on 11/28/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit
import AudioToolbox

public extension UIDevice
{
    enum FeedbackSupportLevel: Int
    {
        case unsupported // iPhone 6 or earlier, or non-iPhone (e.g. iPad)
        case basic // iPhone 6s
        case feedbackGenerator // iPhone 7 and later
    }
}

public extension UIDevice
{
    var feedbackSupportLevel: FeedbackSupportLevel
    {
        guard let rawValue = self.value(forKey: "_feedbackSupportLevel") as? Int else { return .unsupported }
        
        let feedbackSupportLevel = FeedbackSupportLevel(rawValue: rawValue)
        return feedbackSupportLevel ?? .feedbackGenerator // We'll assume raw values greater than 2 still support UIFeedbackGenerator ¯\_(ツ)_/¯
    }
    
    var isVibrationSupported: Bool {
        #if (arch(i386) || arch(x86_64))
            // Return false for iOS simulator
            return false
        #else
            // All iPhones support some form of vibration, and potentially future non-iPhone devices will support taptic feedback
            return (self.model.hasPrefix("iPhone")) || self.feedbackSupportLevel != .unsupported
        #endif
    }
    
    func vibrate()
    {
        guard self.isVibrationSupported else { return }
        
        switch self.feedbackSupportLevel
        {
        case .unsupported: break
        case .basic, .feedbackGenerator: AudioServicesPlaySystemSound(1519) // "peek" vibration
        }
    }
}
