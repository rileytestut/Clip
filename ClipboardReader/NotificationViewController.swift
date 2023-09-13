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
        if let error = self.databaseError
        {
            self.finish(.failure(error))
        }
        else
        {
            self.preparationDispatchGroup.notify(queue: .main) {
                DatabaseManager.shared.savePasteboard { (result) in
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
        self.extensionContext?.dismissNotificationContentExtension()
        
        switch result
        {
        case .success: break
        case .failure(PasteboardError.duplicateItem): break
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
}
