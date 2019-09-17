//
//  ApplicationMonitor.swift
//  Clip
//
//  Created by Riley Testut on 6/27/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit
import AVFoundation
import UserNotifications

private enum UserNotification: String
{
    case appStoppedRunning = "com.rileytestut.Clip.AppStoppedRunning"
}

private extension CFNotificationName
{
    static let altstoreRequestAppState: CFNotificationName = CFNotificationName("com.altstore.RequestAppState.com.rileytestut.Clip" as CFString)
    static let altstoreAppIsRunning: CFNotificationName = CFNotificationName("com.altstore.AppState.Running.com.rileytestut.Clip" as CFString)
}

private let ReceivedApplicationState: @convention(c) (CFNotificationCenter?, UnsafeMutableRawPointer?, CFNotificationName?, UnsafeRawPointer?, CFDictionary?) -> Void =
{ (center, observer, name, object, userInfo) in
    ApplicationMonitor.shared.receivedApplicationStateRequest()
}

class ApplicationMonitor
{
    static let shared = ApplicationMonitor()
    
    let audioEngine = AudioEngine()
    let pasteboardMonitor = PasteboardMonitor()
    
    private(set) var isMonitoring = false
    
    private var backgroundTaskID: UIBackgroundTaskIdentifier?
}

extension ApplicationMonitor
{
    func start()
    {
        guard !self.isMonitoring else { return }
        self.isMonitoring = true
        
        func finish(_ result: Result<Void, Error>)
        {
            switch result
            {
            case .success:
                self.registerForNotifications()
                
            case .failure(let error):
                self.isMonitoring = false
                self.sendNotification(title: NSLocalizedString("Failed to Monitor Clipboard", comment: ""), message: error.localizedDescription)
            }
        }
        
        self.cancelApplicationQuitNotification() // Cancel any notifications from a previous launch.
        self.scheduleApplicationQuitNotification()
        
        DispatchQueue.global().async {
            do
            {
                try self.audioEngine.start()
                
                self.pasteboardMonitor.start() { (result) in
                    finish(result)
                }                
            }
            catch
            {
                finish(.failure(error))
            }
        }
    }
}

private extension ApplicationMonitor
{
    func registerForNotifications()
    {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterAddObserver(center, nil, ReceivedApplicationState, CFNotificationName.altstoreRequestAppState.rawValue, nil, .deliverImmediately)
        
        NotificationCenter.default.addObserver(self, selector: #selector(ApplicationMonitor.audioSessionWasInterrupted(_:)), name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance())
    }
    
    func scheduleApplicationQuitNotification()
    {
        let delay = 5 as TimeInterval
        
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("App Stopped Running", comment: "")
        content.body = NSLocalizedString("Tap this notification to resume monitoring your clipboard.", comment: "")
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay + 1, repeats: false)
        
        let request = UNNotificationRequest(identifier: UserNotification.appStoppedRunning.rawValue, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
        
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
            // If app is still running at this point, we schedule another notification with same identifier.
            // This prevents the currently scheduled notification from displaying, and starts another countdown timer.
            self.scheduleApplicationQuitNotification()
        }
    }
    
    func cancelApplicationQuitNotification()
    {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [UserNotification.appStoppedRunning.rawValue])
    }
    
    func sendNotification(title: String, message: String)
    {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

private extension ApplicationMonitor
{
    @objc func audioSessionWasInterrupted(_ notification: Notification)
    {
        guard
            let userInfo = notification.userInfo,
            let rawType = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: rawType)
        else { return }
        
        switch type
        {
        case .began:
            #if DEBUG
            self.sendNotification(title: "App No Longer Running", message: "Audio Session Interrupted")
            #endif
            
            // Begin background task to reduce chance of us being terminated while audio session is interrupted.
            self.backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "com.rileytestut.Clip.delayTermination") {
                guard let backgroundTaskID = self.backgroundTaskID else { return }
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
            }
            
        case .ended:
            #if DEBUG
            self.sendNotification(title: "App Resumed Running", message: "Audio Session Resumed")
            #endif
            
            if let backgroundTaskID = self.backgroundTaskID
            {
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
            }
            
        @unknown default: break
        }
    }
    
    func receivedApplicationStateRequest()
    {
        guard UIApplication.shared.applicationState != .background else { return }
        
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(center!, CFNotificationName(CFNotificationName.altstoreAppIsRunning.rawValue), nil, nil, true)
    }
}
