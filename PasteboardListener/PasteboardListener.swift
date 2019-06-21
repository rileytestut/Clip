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
import CoreData

import ClipKit

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
        
        UserDefaults.shared.registerAppDefaults()
        
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
        print(UIPasteboard.general.changeCount)
        
        guard case let changeCount = UIPasteboard.general.changeCount, changeCount != self.previousChangeCount else { return }
        
        self.previousChangeCount = changeCount
        self.pasteboardDidUpdate()
    }
    
    func pasteboardDidUpdate()
    {
        guard !UIPasteboard.general.hasColors else { return } // Accessing UIPasteboard.items causes crash as of iOS 12.3 if it contains a UIColor.
        
        print("Did update pasteboard!")
        
        guard let itemProvider = UIPasteboard.general.itemProviders.first else { return }
        guard !itemProvider.registeredTypeIdentifiers.contains(UTI.clipping) else { return } // Ignore copies that we made from the app.
        
        let context = DatabaseManager.shared.persistentContainer.newBackgroundContext()
        PasteboardItemRepresentation.representations(for: itemProvider, in: context) { (representations) in
            guard let pasteboardItem = PasteboardItem(representations: representations, context: context) else { return }
            print(pasteboardItem)
            
            do
            {
                let fetchRequest = PasteboardItem.fetchRequest() as NSFetchRequest<PasteboardItem>
                fetchRequest.predicate = NSPredicate(format: "%K == NO", #keyPath(PasteboardItem.isMarkedForDeletion))
                fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \PasteboardItem.date, ascending: false)]
                fetchRequest.relationshipKeyPathsForPrefetching = ["representations"]
                fetchRequest.includesPendingChanges = false
                fetchRequest.fetchLimit = 1
                
                if let previousItem = try context.fetch(fetchRequest).first
                {
                    let representations = pasteboardItem.representations.reduce(into: [:], { ($0[$1.type] = $1.value as? NSObject) })
                    let previousRepresentations = previousItem.representations.reduce(into: [:], { ($0[$1.type] = $1.value as? NSObject) })
                    
                    guard representations != previousRepresentations else {
                        return
                    }
                }
            }
            catch
            {
                print("Failed to fetch previous pasteboard item.", error)
            }
            
            context.transactionAuthor = "com.rileytestut.ClipboardManager.PasteboardListener"
            do { try context.save() } catch { print("Error saving pasteboard data.", error) }
            
            let center = CFNotificationCenterGetDarwinNotifyCenter()
            CFNotificationCenterPostNotification(center, .didChangePasteboard, nil, nil, true)
            
            let content = UNMutableNotificationContent()
            content.title = NSLocalizedString("Clipboard Saved", comment: "")
            content.body = pasteboardItem.preferredRepresentation?.stringValue ?? pasteboardItem.preferredRepresentation?.attributedStringValue?.string ?? pasteboardItem.preferredRepresentation?.urlValue?.absoluteString ?? ""
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
            
            let request = UNNotificationRequest(identifier: "ClipboardChanged", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request) { (error) in
                if let error = error {
                    print(error)
                }
            }
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
