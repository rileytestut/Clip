//
//  NotificationViewController.swift
//  NotificationClipboard
//
//  Created by Riley Testut on 12/2/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit
import UserNotifications
import UserNotificationsUI

import ClipKit
import Roxas

extension NotificationViewController
{
    private enum Error: LocalizedError
    {
        case unsupportedImageFormat
        case unsupportedItem
        case noItem
        case duplicateItem
        
        var errorDescription: String? {
            switch self
            {
            case .unsupportedImageFormat: return NSLocalizedString("Unsupported image format.", comment: "")
            case .unsupportedItem: return NSLocalizedString("Unsupported clipboard item.", comment: "")
            case .noItem: return NSLocalizedString("No clipboard item.", comment: "")
            case .duplicateItem: return NSLocalizedString("Duplicate item.", comment: "")
            }
        }
    }
}

class NotificationViewController: UIViewController, UNNotificationContentExtension
{
    @IBOutlet private var activityIndicatorView: UIActivityIndicatorView!
    
    private let preparationDispatchGroup = DispatchGroup()
    private var databaseError: Swift.Error?
    
    required init?(coder: NSCoder)
    {
        super.init(coder: coder)
        
        UserDefaults.shared.registerAppDefaults()
        
        self.preparationDispatchGroup.enter()

        DatabaseManager.shared.persistentContainer.shouldAddStoresAsynchronously = true
        DatabaseManager.shared.prepare { (result) in
            switch result
            {
            case .failure(let error): self.databaseError = error
            case .success: break
            }

            self.preparationDispatchGroup.leave()
        }
    }
    
    func didReceive(_ notification: UNNotification)
    {
        // Dismiss notification ASAP and continue saving in background.
        self.extensionContext?.dismissNotificationContentExtension()
        
        if let error = self.databaseError
        {
            self.finish(.failure(error))
        }
        else
        {
            self.preparationDispatchGroup.notify(queue: .main) {
                self.saveClipboard() { (result) in
                    self.finish(result)
                }
            }
        }
    }
}

private extension NotificationViewController
{
    func finish(_ result: Result<Void, Swift.Error>)
    {
        switch result
        {
        case .success: break
        case .failure(Error.duplicateItem): break
            
        case .failure(let error):
            let content = UNMutableNotificationContent()
            content.title = NSLocalizedString("Failed to Save Clipboard", comment: "")
            content.body = error.localizedDescription
            
            let request = UNNotificationRequest(identifier: "SaveError", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request) { (error) in
                if let error = error {
                    print(error)
                }
            }
        }
    }
    
    func saveClipboard(completionHandler: @escaping (Result<Void, Swift.Error>) -> Void)
    {
        do
        {
            guard !UIPasteboard.general.hasColors else {
                throw Error.unsupportedItem // Accessing UIPasteboard.items causes crash as of iOS 12.3 if it contains a UIColor.
            }
            
            print("Did update pasteboard!")
            
            guard let itemProvider = UIPasteboard.general.itemProviders.first else { throw Error.noItem }
            guard !itemProvider.registeredTypeIdentifiers.contains(UTI.clipping) else { throw Error.duplicateItem } // Ignore copies that we made from the app.
            
            let context = DatabaseManager.shared.persistentContainer.newBackgroundContext()
            PasteboardItemRepresentation.representations(for: itemProvider, in: context) { (representations) in
                do
                {
                    guard let pasteboardItem = PasteboardItem(representations: representations, context: context) else { throw Error.noItem }
                    print(pasteboardItem)
                    
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
                            throw Error.duplicateItem
                        }
                    }
                    
                    guard let _ = pasteboardItem.preferredRepresentation else { throw Error.unsupportedItem }
                    
                    context.transactionAuthor = "com.rileytestut.Clip.PasteboardReader"
                    try context.save()
                    
                    let center = CFNotificationCenterGetDarwinNotifyCenter()
                    CFNotificationCenterPostNotification(center, .didChangePasteboard, nil, nil, true)
                    
                    DispatchQueue.main.async {
                        completionHandler(.success(()))
                    }
                }
                catch
                {
                    DispatchQueue.main.async {
                        print("Failed to handle pasteboard item.", error)
                        completionHandler(.failure(error))
                    }
                }
            }
        }
        catch
        {
            completionHandler(.failure(error))
        }
    }
}
