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

@objc(PasteboardItemRepresentation)
class PasteboardItemRepresentation: NSManagedObject
{
    /* Properties */
    @NSManaged private(set) var uti: String
    
    @NSManaged private var data: Data?
    @NSManaged private var string: String?
    @NSManaged private var url: URL?
    
    /* Relationships */
    @NSManaged private var item: PasteboardItem?
    
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?)
    {
        super.init(entity: entity, insertInto: context)
    }
    
    init?(uti: String, value: Any, context: NSManagedObjectContext)
    {
        super.init(entity: PasteboardItemRepresentation.entity(), insertInto: nil)
        
        self.uti = uti
        
        switch (uti, value)
        {
        case (let uti as CFString, let string as String) where UTTypeConformsTo(uti, kUTTypeText): self.string = string
        case (let uti as CFString, let url as URL) where UTTypeConformsTo(uti, kUTTypeURL): self.url = url
        case (let uti as CFString, let imageData as Data) where UTTypeConformsTo(uti, kUTTypeImage): self.data = imageData
        case (let uti as CFString, let image as UIImage) where UTTypeConformsTo(uti, kUTTypePNG):
            guard let data = image.pngData() else { return nil }
            self.data = data
            
        case (let uti as CFString, let image as UIImage) where UTTypeConformsTo(uti, kUTTypeImage):
            guard let data = image.jpegData(compressionQuality: 0.85) else { return nil }
            self.data = data
            
        case (_, let unknownData as Data): self.data = unknownData
        default: return nil
        }
        
        context.insert(self)
    }
}

extension PasteboardItemRepresentation
{
    @nonobjc class func fetchRequest() -> NSFetchRequest<PasteboardItemRepresentation>
    {
        return NSFetchRequest<PasteboardItemRepresentation>(entityName: "PasteboardItemRepresentation")
    }
}

extension PasteboardItemRepresentation
{
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
        
        guard let data = self.string?.data(using: .utf8) else { return nil }
        
        let attributedString = try? NSAttributedString(data: data, options: [.documentType : type], documentAttributes: nil)
        return attributedString
    }
}
