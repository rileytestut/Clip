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
import ImageIO

import ClipKit

import Roxas

extension PasteboardListener
{
    private enum Error: LocalizedError
    {
        case unsupportedImageFormat
        
        var errorDescription: String? {
            switch self
            {
            case .unsupportedImageFormat: return NSLocalizedString("The image is in an unsupported format.", comment: "")
            }
        }
    }
}

@objc(CLIPPasteboardListener)
public class PasteboardListener: NSObject, NSExtensionRequestHandling
{
    static let shared = PasteboardListener()
    
    private var pollingTimer: Timer?
    private var previousChangeCount: Int?
    
    var isListening = false
    
    deinit
    {
        self.pollingTimer?.invalidate()
    }
    
    public func beginRequest(with context: NSExtensionContext)
    {
        guard self === PasteboardListener.shared else {
            return PasteboardListener.shared.beginRequest(with: context)
        }
        
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
        guard !self.isListening else { return }
        
        self.isListening = true
        
        DispatchQueue.main.async {
            self.previousChangeCount = UIPasteboard.general.changeCount
            self.pollingTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(PasteboardListener.poll), userInfo: nil, repeats: true)
        }
    }
    
    @objc func poll()
    {
        print(UIPasteboard.general.changeCount)
        
        let changeCount = UIPasteboard.general.changeCount
        
        guard changeCount != self.previousChangeCount else { return }
        self.previousChangeCount = changeCount
        
        guard changeCount != 0 else {
            #if DEBUG
            let content = UNMutableNotificationContent()
            content.title = NSLocalizedString("An Error Occured", comment: "")
            content.body = NSLocalizedString("UIKit is reporting change count of 0.", comment: "")
            
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
            #endif
            
            return
        }
        
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
            
            guard let preferredRepresentation = pasteboardItem.preferredRepresentation else { return }
            
            context.transactionAuthor = "com.rileytestut.Clip.PasteboardListener"
            do { try context.save() } catch { print("Error saving pasteboard data.", error) }
            
            let center = CFNotificationCenterGetDarwinNotifyCenter()
            CFNotificationCenterPostNotification(center, .didChangePasteboard, nil, nil, true)
            
            let content = UNMutableNotificationContent()
            content.title = NSLocalizedString("Clipboard Saved", comment: "")
            
            switch preferredRepresentation.type
            {
            case .text, .attributedText, .url:
                content.body = pasteboardItem.preferredRepresentation?.stringValue ?? pasteboardItem.preferredRepresentation?.attributedStringValue?.string ?? pasteboardItem.preferredRepresentation?.urlValue?.absoluteString ?? ""
                
            case .image:
                guard let data = preferredRepresentation.dataValue else { return }
                
                let temporaryURL = FileManager.default.uniqueTemporaryURL()
                
                do
                {
                    try self.writeThumbnailData(data, to: temporaryURL, uti: preferredRepresentation.uti)
                    
                    let attachment = try UNNotificationAttachment(identifier: "", url: temporaryURL, options: [UNNotificationAttachmentOptionsTypeHintKey: preferredRepresentation.uti])
                    content.attachments = [attachment]
                }
                catch
                {
                    print("Failed to load image data.", error)
                    
                    content.body = NSLocalizedString("Image", comment: "")
                }
            }
                        
            let request = UNNotificationRequest(identifier: "ClipboardChanged", content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request) { (error) in
                if let error = error {
                    print(error)
                }
            }
        }
    }
    
    func writeThumbnailData(_ data: Data, to fileURL: URL, uti: String) throws
    {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else { throw Error.unsupportedImageFormat }
        
        let thumbnailOptions: [CFString: Any] = [kCGImageSourceThumbnailMaxPixelSize: 640,
                                                 kCGImageSourceCreateThumbnailFromImageAlways: true,
                                                 kCGImageSourceCreateThumbnailWithTransform: true]
        
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, thumbnailOptions as CFDictionary) else { throw Error.unsupportedImageFormat }
        
        guard let destination = CGImageDestinationCreateWithURL(fileURL as CFURL, uti as CFString, 1, nil) else { throw Error.unsupportedImageFormat }
        CGImageDestinationAddImage(destination, thumbnail, nil);
        
        guard CGImageDestinationFinalize(destination) else { throw Error.unsupportedImageFormat }
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
