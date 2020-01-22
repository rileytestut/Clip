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
                
        self.registerForNotifications()
        completionHandler(.success(()))
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
        
        #if !targetEnvironment(simulator)
        let pasteboardFramework = Bundle(path: "/System/Library/PrivateFrameworks/Pasteboard.framework")!
        pasteboardFramework.load()
        
        let PBServerConnection = NSClassFromString("PBServerConnection") as AnyObject
        _ = PBServerConnection.perform(NSSelectorFromString("beginListeningToPasteboardChangeNotifications"))
        #endif
        
        NotificationCenter.default.addObserver(self, selector: #selector(PasteboardMonitor.pasteboardDidUpdate), name: Notification.Name("com.apple.pasteboard.changed"), object: nil)
    }
    
    @objc func pasteboardDidUpdate()
    {
        DispatchQueue.main.async {
            if UIApplication.shared.applicationState != .background
            {
                // Don't present notifications for items copied from within Clip.
                guard !UIPasteboard.general.contains(pasteboardTypes: [UTI.clipping]) else { return }
            }
            
            UNUserNotificationCenter.current().getNotificationSettings { (settings) in
                if settings.soundSetting == .enabled
                {
                    UIDevice.current.vibrate()
                }
            }            
            
            let content = UNMutableNotificationContent()
            content.categoryIdentifier = UNNotificationCategory.clipboardReaderIdentifier
            content.title = NSLocalizedString("Clipboard Changed", comment: "")
            content.body = NSLocalizedString("Swipe down to save to Clip.", comment: "")
            
            let request = UNNotificationRequest(identifier: "ClipboardChanged", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request) { (error) in
                if let error = error {
                    print(error)
                }
            }
        }
    }
}

private extension PasteboardMonitor
{
    func didChangePasteboard()
    {
        DatabaseManager.shared.refresh()
        
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["ClipboardChanged"])
    }
}
