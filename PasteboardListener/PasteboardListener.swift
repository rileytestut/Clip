//
//  PasteboardListener.swift
//  PasteboardListener
//
//  Created by Riley Testut on 6/12/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit
import UserNotifications
import CoreAudioKit

import ClipKit

extension PasteboardListener
{
    public static let didChangePasteboardNotification: CFNotificationName = CFNotificationName("com.rileytestut.ClipboardManager.DidChangePasteboard" as CFString)
}

@objc(CLIPPasteboardListener)
public class PasteboardListener: NSObject, NSExtensionRequestHandling
{
    private var pollingTimer: Timer?
    private var previousChangeCount: Int?
    
    deinit
    {
        self.pollingTimer?.invalidate()
    }
    
    public func beginRequest(with context: NSExtensionContext)
    {
        print("Beginning Request...")
        
        DatabaseManager.shared.persistentContainer.shouldAddStoresAsynchronously = true
        DatabaseManager.shared.prepare { (result) in
            switch result
            {
            case .failure(let error): context.cancelRequest(withError: error)
            case .success: self.start()
            }
        }
    }
}

private extension PasteboardListener
{
    func start()
    {
        DispatchQueue.main.async {
            self.previousChangeCount = UIPasteboard.general.changeCount
            self.pollingTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(PasteboardListener.poll), userInfo: nil, repeats: true)
        }
    }
    
    @objc func poll()
    {
        guard case let changeCount = UIPasteboard.general.changeCount, changeCount != self.previousChangeCount else { return }
        
        self.previousChangeCount = changeCount
        self.pasteboardDidUpdate()
    }
    
    func pasteboardDidUpdate()
    {
        guard !UIPasteboard.general.hasColors else { return } // Accessing UIPasteboard.items causes crash as of iOS 12.3 if it contains a UIColor.
        
        print("Did update pasteboard!")
        
        let content = UNMutableNotificationContent()
        content.title = "Clipboard Saved"
        content.body = UIPasteboard.general.string ?? "Unknown Type"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        
        let request = UNNotificationRequest(identifier: "ClipboardChanged", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { (error) in
            if let error = error {
                print(error)
            }
        }
        
        DatabaseManager.shared.persistentContainer.performBackgroundTask { (context) in
            let pasteboardItems = UIPasteboard.general.items.compactMap { (representations) -> PasteboardItem? in
                let representations = representations.compactMap { PasteboardItemRepresentation(uti: $0, value: $1, context: context) }
                
                let pasteboardItem = PasteboardItem(representations: representations, context: context)
                return pasteboardItem
            }
            
            print(pasteboardItems)
            
            context.transactionAuthor = "com.rileytestut.ClipboardManager.PasteboardListener"
            do { try context.save() } catch { print("Error saving pasteboard data.", error) }
            
            let center = CFNotificationCenterGetDarwinNotifyCenter()
            CFNotificationCenterPostNotification(center, PasteboardListener.didChangePasteboardNotification, nil, nil, true)
        }
    }
}

extension PasteboardListener: AUAudioUnitFactory
{
    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit
    {
        let audioUnit = try! ListenerUnit(componentDescription: componentDescription, options: [])
        return audioUnit
    }
}
