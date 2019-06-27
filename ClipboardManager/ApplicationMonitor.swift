//
//  ApplicationMonitor.swift
//  ClipboardManager
//
//  Created by Riley Testut on 6/27/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit
import UserNotifications

private enum Notification: String
{
    case appStoppedRunning = "com.rileytestut.ClipboardManager.AppStoppedRunning"
}

class ApplicationMonitor
{
    static let shared = ApplicationMonitor()
    
    private(set) var isMonitoring = false
}

extension ApplicationMonitor
{
    func start()
    {
        guard !self.isMonitoring else { return }
        self.isMonitoring = true
        
        // Cancel any notifications from a previous launch.
        self.cancelApplicationQuitNotification()
        
        self.scheduleApplicationQuitNotification()
    }
}

private extension ApplicationMonitor
{
    func scheduleApplicationQuitNotification()
    {
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("App Stopped Running", comment: "")
        content.body = NSLocalizedString("Tap this notification to resume monitoring your clipboard.", comment: "")
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 6.0, repeats: false)
        
        let request = UNNotificationRequest(identifier: Notification.appStoppedRunning.rawValue, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
        
        DispatchQueue.global().asyncAfter(deadline: .now() + 5.0) {
            // If app is still running at this point, we schedule another notification with same identifier.
            // This prevents the currently scheduled notification from displaying, and starts another countdown timer.
            self.scheduleApplicationQuitNotification()
        }
    }
    
    func cancelApplicationQuitNotification()
    {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Notification.appStoppedRunning.rawValue])
    }
}
