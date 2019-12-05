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
    @IBOutlet private var textLabel: UILabel!
    @IBOutlet private var activityIndicatorView: UIActivityIndicatorView!
    
    private var databaseError: Swift.Error?
    
    private let dispatchGroup = DispatchGroup()
    
    required init?(coder: NSCoder)
    {
        super.init(coder: coder)
        
        UserDefaults.shared.registerAppDefaults()
        
        self.dispatchGroup.enter()
        
        DatabaseManager.shared.persistentContainer.shouldAddStoresAsynchronously = true
        DatabaseManager.shared.prepare { (result) in
            switch result
            {
            case .failure(let error): self.databaseError = error
            case .success: break
            }
            
            self.dispatchGroup.leave()
        }
    }
    
    func didReceive(_ notification: UNNotification)
    {
        if let error = self.databaseError
        {
            self.finish(.failure(error))
        }
        else
        {
            self.extensionContext?.dismissNotificationContentExtension()
            
            self.textLabel.isHidden = true
            self.activityIndicatorView.startAnimating()

            self.dispatchGroup.notify(queue: .main) {
                self.saveClipboard() { (result) in
                    self.finish(result)
                }
            }
        }
    }
    
    func finish(_ result: Result<Void, Swift.Error>)
    {
        switch result
        {
        case .failure(let error):
            
            let content = UNMutableNotificationContent()
            content.title = NSLocalizedString("Save Failed", comment: "")
            content.body = error.localizedDescription
            
            let request = UNNotificationRequest(identifier: "SaveError", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request) { (error) in
                if let error = error {
                    print(error)
                }
            }
            
        case .success:
            self.textLabel.isHidden = true
            self.activityIndicatorView.startAnimating()
                        
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.extensionContext?.dismissNotificationContentExtension()
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
//            guard !itemProvider.registeredTypeIdentifiers.contains(UTI.clipping) else { return } // Ignore copies that we made from the app.
            
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
                    
                    context.transactionAuthor = "com.rileytestut.Clip.PasteboardListener"
                    do { try context.save() } catch { print("Error saving pasteboard data.", error) }
                    
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
