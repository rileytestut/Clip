//
//  IntentHandler.swift
//  Clip
//
//  Created by Riley Testut on 10/30/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import Intents
import CoreData

import ClipKit

@available(iOS 14, *)
public class IntentHandler: NSObject
{
}

@available(iOS 14, *)
extension IntentHandler: SaveToClipIntentHandling
{
    public func handle(intent: SaveToClipIntent, completion: @escaping (SaveToClipIntentResponse) -> Swift.Void)
    {
        DatabaseManager.shared.prepare { (result) in
            do
            {
                try result.get()
                
                guard let item = intent.item else { return completion(.init(code: .unspecified, userActivity: nil)) }
                
                let itemProvider = NSItemProvider(object: item as NSString)
                DatabaseManager.shared.save(itemProvider) { (result) in
                    switch result
                    {
                    case .success, .failure(PasteboardError.duplicateItem): completion(.init(code: .success, userActivity: nil))
                    case .failure(let error): completion(.failure(localizedDescription: error.localizedDescription))
                    }
                }
            }
            catch
            {
                completion(.failure(localizedDescription: error.localizedDescription))
            }
        }
    }
}

@available(iOS 14, *)
extension IntentHandler: CopyClippingIntentHandling
{
    public func provideClippingOptionsCollection(for intent: CopyClippingIntent, with completion: @escaping (INObjectCollection<Clipping>?, Error?) -> Void)
    {
        DatabaseManager.shared.prepare { (result) in
            switch result
            {
            case .failure(let error):
                print("Failed to prepare database for Paste intent.", error)
                completion(nil, error)

            case .success:
                DatabaseManager.shared.persistentContainer.performBackgroundTask { (context) in
                    let fetchRequest = PasteboardItem.fetchRequest() as NSFetchRequest<PasteboardItem>
                    fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \PasteboardItem.date, ascending: false)]

                    do
                    {
                        let clippings = try context.fetch(fetchRequest).compactMap { (pasteboardItem) -> Clipping? in
                            guard let representation = pasteboardItem.preferredRepresentation else { return nil }

                            let display: String

                            switch representation.type
                            {
                            case .text, .attributedText, .url: display = representation.stringValue ?? NSLocalizedString("Unknown", comment: "")
                            case .image: display = NSLocalizedString("Image", comment: "")
                            }

                            let identifier = pasteboardItem.objectID.uriRepresentation().absoluteString
                            let clipping = Clipping(identifier: identifier, display: display, subtitle: representation.type.localizedName, image: nil)

                            if representation.type == .image, let imageData = representation.dataValue
                            {
                                clipping.displayImage = INImage(imageData: imageData)
                            }

                            return clipping
                        }

                        let collection = INObjectCollection(items: clippings)
                        completion(collection, nil)
                    }
                    catch
                    {
                        print("Failed to fetch clippings for Paste intent.", error)
                        completion(nil, error)
                    }
                }
            }
        }
    }

    public func resolveClipping(for intent: CopyClippingIntent, with completion: @escaping (ClippingResolutionResult) -> Void)
    {
        if let clipping = intent.clipping
        {
            completion(.success(with: clipping))
        }
        else
        {
            completion(ClippingResolutionResult.needsValue())
        }
    }

    public func handle(intent: CopyClippingIntent, completion: @escaping (CopyClippingIntentResponse) -> Void)
    {
        DatabaseManager.shared.persistentContainer.performBackgroundTask { (context) in

            guard let clipping = intent.clipping,
                  let identifier = clipping.identifier,
                  let objectIDURI = URL(string: identifier),
                  let persistentStoreCoordinator = context.persistentStoreCoordinator,
                  let objectID = persistentStoreCoordinator.managedObjectID(forURIRepresentation: objectIDURI)
            else { return completion(CopyClippingIntentResponse(code: .failure, userActivity: nil)) }

            do
            {
                guard let pasteboardItem = try context.existingObject(with: objectID) as? PasteboardItem else { return completion(CopyClippingIntentResponse(code: .failure, userActivity: nil)) }

                let center = CFNotificationCenterGetDarwinNotifyCenter()
                CFNotificationCenterPostNotification(center, .ignoreNextPasteboardChange, nil, nil, true)

                UIPasteboard.general.copy(pasteboardItem)

                completion(CopyClippingIntentResponse(code: .success, userActivity: nil))
            }
            catch
            {
                print("Failed to copy clipping for Paste intent.", error)
                completion(CopyClippingIntentResponse(code: .failure, userActivity: nil))
            }
        }
    }
}
