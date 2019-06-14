//
//  PasteboardItemRepresentation.swift
//  ClipboardManager
//
//  Created by Riley Testut on 6/11/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit
import CoreData
import MobileCoreServices

extension PasteboardItemRepresentation
{
    @objc public enum RepresentationType: Int16, CaseIterable
    {
        case text
        case attributedText
        case url
        case image
    }
}

@objc(PasteboardItemRepresentation)
public class PasteboardItemRepresentation: NSManagedObject
{
    /* Properties */
    @NSManaged public private(set) var uti: String
    @NSManaged public private(set) var type: RepresentationType
    
    @NSManaged private var data: Data?
    @NSManaged private var string: String?
    @NSManaged private var url: URL?
    
    /* Relationships */
    @NSManaged public var item: PasteboardItem?
    @NSManaged private var preferringItem: PasteboardItem? // Inverse of PasteboardItem.preferredRepresentation.
    
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?)
    {
        super.init(entity: entity, insertInto: context)
    }
    
    private init(uti: String, type: RepresentationType, context: NSManagedObjectContext)
    {
        super.init(entity: PasteboardItemRepresentation.entity(), insertInto: context)
        self.uti = uti
        self.type = type
    }
    
    private convenience init(uti: String, text: String, context: NSManagedObjectContext)
    {
        self.init(uti: uti, type: .text, context: context)
        self.string = text
    }
    
    private convenience init(uti: String, data: Data, type: RepresentationType, context: NSManagedObjectContext)
    {
        self.init(uti: uti, type: type, context: context)
        self.data = data
    }
    
    private convenience init(uti: String, url: URL, context: NSManagedObjectContext)
    {
        self.init(uti: uti, type: .url, context: context)
        self.url = url
    }
    
    public static func representations(for itemProvider: NSItemProvider, in context: NSManagedObjectContext, completionHandler: @escaping ([PasteboardItemRepresentation]) -> Void)
    {
        var representations = [PasteboardItemRepresentation]()
        
        let dispatchGroup = DispatchGroup()
        
        let supportedTextUTIs = [kUTTypeUTF8PlainText, kUTTypePlainText, kUTTypeText]
        if let uti = supportedTextUTIs.first(where: { itemProvider.hasItemConformingToTypeIdentifier($0 as String) }), itemProvider.canLoadObject(ofClass: NSString.self)
        {
            dispatchGroup.enter()
            
            itemProvider.loadObject(ofClass: NSString.self) { (text, error) in
                context.perform {
                    switch Result(text, error)
                    {
                    case .failure(let error): print(error)
                    case .success(let text):
                        let representation = PasteboardItemRepresentation(uti: uti as String, text: text as! String, context: context)
                        representations.append(representation)
                    }
                    
                    dispatchGroup.leave()
                }
            }
        }
        
        let supportedAttributedTextUTIs = [kUTTypeRTF, kUTTypeHTML, kUTTypeFlatRTFD, kUTTypeRTFD]
        if let uti = supportedAttributedTextUTIs.first(where: { itemProvider.hasItemConformingToTypeIdentifier($0 as String) }), itemProvider.canLoadObject(ofClass: NSAttributedString.self)
        {
            dispatchGroup.enter()
            
            itemProvider.loadDataRepresentation(forTypeIdentifier: uti as String) { (data, error) in
                context.perform {
                    switch Result(data, error)
                    {
                    case .failure(let error): print(error)
                    case .success(let data):
                        let representation = PasteboardItemRepresentation(uti: uti as String, data: data, type: .attributedText, context: context)
                        representations.append(representation)
                    }
                    
                    dispatchGroup.leave()
                }
            }
        }
        
        let supportedImageUTIs = [kUTTypePNG, kUTTypeJPEG, kUTTypeImage]
        if let uti = supportedImageUTIs.first(where: { itemProvider.hasItemConformingToTypeIdentifier($0 as String) }), itemProvider.canLoadObject(ofClass: UIImage.self)
        {
            dispatchGroup.enter()
            
            itemProvider.loadDataRepresentation(forTypeIdentifier: uti as String) { (data, error) in
                context.perform {
                    switch Result(data, error)
                    {
                    case .failure(let error): print(error)
                    case .success(let data):
                        let representation = PasteboardItemRepresentation(uti: uti as String, data: data, type: .image, context: context)
                        representations.append(representation)
                    }
                    
                    dispatchGroup.leave()
                }
            }
        }
        
        let supportedURLUTIs = [kUTTypeFileURL, kUTTypeURL]
        if let uti = supportedURLUTIs.first(where: { itemProvider.hasItemConformingToTypeIdentifier($0 as String) }), itemProvider.canLoadObject(ofClass: NSURL.self)
        {
            dispatchGroup.enter()
            
            itemProvider.loadObject(ofClass: NSURL.self) { (url, error) in
                context.perform {
                    switch Result(url, error)
                    {
                    case .failure(let error as NSError) where error.domain == NSItemProvider.errorDomain && error.code == NSItemProvider.ErrorCode.unavailableCoercionError.rawValue:
                        // Ignore, corrupted data.
                        break
                        
                    case .failure(let error): print("Failed to load URL.", error)
                        
                    case .success(let url):
                        let representation = PasteboardItemRepresentation(uti: uti as String, url: url as! URL, context: context)
                        representations.append(representation)
                    }
                    
                    dispatchGroup.leave()
                }
            }
        }
        
        dispatchGroup.notify(queue: .global()) {
            context.perform {
                let sortedRepresentations = representations.sorted(by: { (a, b) -> Bool in
                    guard let indexA = itemProvider.registeredTypeIdentifiers.firstIndex(of: a.uti) else { return false }
                    guard let indexB = itemProvider.registeredTypeIdentifiers.firstIndex(of: b.uti) else { return false }
                    
                    return indexA < indexB
                })
                
                completionHandler(sortedRepresentations)
            }
        }
    }
}

extension PasteboardItemRepresentation
{
    @nonobjc class func fetchRequest() -> NSFetchRequest<PasteboardItemRepresentation>
    {
        return NSFetchRequest<PasteboardItemRepresentation>(entityName: "PasteboardItemRepresentation")
    }
}

public extension PasteboardItemRepresentation
{
    var value: Any? {
        switch self.type
        {
        case .text: return self.stringValue
        case .attributedText: return self.attributedStringValue
        case .url: return self.urlValue
        case .image: return self.imageValue
        }
    }
    
    var pasteboardValue: Any? {
        switch self.type
        {
        case .text: return self.stringValue
        case .attributedText: return self.data
        case .url: return self.urlValue
        case .image: return self.data
        }
    }
    
    var stringValue: String? {
        return self.string
    }
    
    var imageValue: UIImage? {
        guard let data = self.data, let image = UIImage(data: data) else { return nil }
        return image
    }
    
    var urlValue: URL? {
        return self.url
    }
    
    var dataValue: Data? {
        return self.data
    }
    
    var attributedStringValue: NSAttributedString? {
        let type: NSAttributedString.DocumentType
        
        switch self.uti
        {
        case let uti as CFString where UTTypeConformsTo(uti, kUTTypeRTF): type = .rtf
        case let uti as CFString where UTTypeConformsTo(uti, kUTTypeHTML): type = .html
            
        case let uti as CFString where UTTypeConformsTo(uti, kUTTypeRTFD): type = .rtfd
        case let uti as CFString where UTTypeConformsTo(uti, kUTTypeFlatRTFD): type = .rtfd
            
        default: return nil
        }
        
        guard let data = self.data ?? self.string?.data(using: .utf8) else { return nil }
        
        let attributedString = try? NSAttributedString(data: data, options: [.documentType : type], documentAttributes: nil)
        return attributedString
    }
}
