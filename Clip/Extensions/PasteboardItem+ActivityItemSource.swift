//
//  PasteboardItem+ActivityItemSource.swift
//  Clip
//
//  Created by Riley Testut on 6/14/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import MobileCoreServices

import ClipKit

extension PasteboardItem: UIActivityItemSource
{
    public func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any
    {
        guard let representation = self.preferredRepresentation else { return NSNull() }
        
        switch representation.type
        {
        case .text: return representation.stringValue ?? ""
        case .attributedText: return representation.attributedStringValue ?? NSAttributedString(string: "")
        case .url: return representation.urlValue ?? URL(string: "http://apple.com")!
        case .image: return representation.imageValue ?? UIImage()
        }
    }
    
    public func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String
    {
        return self.preferredRepresentation?.uti ?? kUTTypeImage as String
    }
    
    public func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any?
    {
        guard let representation = self.preferredRepresentation else { return nil }
        
        if activityType == UIActivity.ActivityType.copyToPasteboard
        {
            let itemProvider = NSItemProvider()            
            
            for representation in self.representations
            {
                itemProvider.registerItem(forTypeIdentifier: representation.uti) { (completionHandler, expectedClass, options) in
                    completionHandler?(representation.pasteboardValue as? NSSecureCoding, nil)
                }
            }

            // Add our own UTI representation to distinguish from other copies.
            itemProvider.registerItem(forTypeIdentifier: UTI.clipping) { (completionHandler, expectedClass, options) in
                completionHandler?([:] as NSDictionary, nil)
            }
            
            return itemProvider
        }
        else
        {
            // _Don't_ return pasteboard value, instead return the logical object value.
            // This way, inline data such as text won't accidentally appear as attachments in some share extensions.
            return representation.value
        }
    }
}
