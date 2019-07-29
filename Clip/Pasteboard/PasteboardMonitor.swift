//
//  PasteboardMonitor.swift
//  Clip
//
//  Created by Riley Testut on 6/11/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit
import AVFoundation
import UserNotifications

import ClipKit
import Roxas

private let PasteboardMonitorDidChangePasteboard: @convention(c) (CFNotificationCenter?, UnsafeMutableRawPointer?, CFNotificationName?, UnsafeRawPointer?, CFDictionary?) -> Void =
{ (center, observer, name, object, userInfo) in
    ApplicationMonitor.shared.pasteboardMonitor.didChangePasteboard()
}

class PasteboardMonitor
{
    private(set) var isStarted = false
    
    private let feedbackGenerator = UINotificationFeedbackGenerator()
}

extension PasteboardMonitor
{
    func start(completionHandler: @escaping (Result<Void, Error>) -> Void)
    {
        guard !self.isStarted else { return }
        self.isStarted = true
        
        ApplicationMonitor.shared.audioEngine.launchAudioUnitExtension(for: .listenerUnit) { (result) in
            switch result
            {
            case .failure(let error):
                self.isStarted = false
                completionHandler(.failure(error))
                
            case .success:
                self.registerForNotifications()                
                completionHandler(.success(()))
            }
        }
    }
    
    func copy(_ pasteboardItem: PasteboardItem)
    {
        var representations = pasteboardItem.representations.reduce(into: [:]) { $0[$1.uti] = $1.pasteboardValue }
        representations[UTI.clipping] = [:]
        
        UIPasteboard.general.setItems([representations], options: [:])
    }
}

private extension PasteboardMonitor
{
    func registerForNotifications()
    {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterAddObserver(center, nil, PasteboardMonitorDidChangePasteboard, CFNotificationName.didChangePasteboard.rawValue, nil, .deliverImmediately)
        
        NotificationCenter.default.addObserver(self, selector: #selector(PasteboardMonitor.audioUnitExtensionDidStop(_:)), name: Notification.Name(String(kAudioComponentInstanceInvalidationNotification)), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(PasteboardMonitor.audioSessionWasInterrupted(_:)), name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance())
        NotificationCenter.default.addObserver(self, selector: #selector(PasteboardMonitor.applicationWillEnterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    func relaunchAudioUnitExtension()
    {
        ApplicationMonitor.shared.audioEngine.launchAudioUnitExtension(for: .listenerUnit) { (result) in
            guard let error = result.error else { return }
            
            let content = UNMutableNotificationContent()
            content.title = NSLocalizedString("Failed to Resume Monitoring Clipboard", comment: "")
            content.body = error.localizedDescription
            
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        }
    }
}

private extension PasteboardMonitor
{
    func didChangePasteboard()
    {
        DatabaseManager.shared.refresh()
        
        UIDevice.current.vibrate()
    }
    
    @objc func audioUnitExtensionDidStop(_ notification: Notification)
    {
        guard let audioUnit = notification.object as? AUAudioUnit, audioUnit.componentDescription == .listenerUnit else { return }
        
        print("Restarting audio unit extension...")
        
        self.relaunchAudioUnitExtension()
    }
    
    @objc func audioSessionWasInterrupted(_ notification: Notification)
    {
        guard
            let userInfo = notification.userInfo,
            let rawType = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: rawType)
        else { return }
        
        switch type
        {
        case .began: break
        case .ended: self.relaunchAudioUnitExtension()
        @unknown default: break
        }
    }
    
    @objc func applicationWillEnterForeground(_ notification: Notification)
    {
        self.relaunchAudioUnitExtension()
    }
}
