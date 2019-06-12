//
//  PasteboardItem.swift
//  ClipboardManager
//
//  Created by Riley Testut on 6/11/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import CoreData
import MobileCoreServices

@objc(PasteboardItem)
class PasteboardItem: NSManagedObject
{
    /* Properties */
    @NSManaged private(set) var date: Date
    
    /* Relationships */
    @nonobjc var representations: [PasteboardItemRepresentation] {
        return self._representations.array as! [PasteboardItemRepresentation]
    }
    @NSManaged @objc(representations) private var _representations: NSOrderedSet
    
    private override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?)
    {
        super.init(entity: entity, insertInto: context)
    }
    
    init?(representations: [PasteboardItemRepresentation], context: NSManagedObjectContext)
    {
        guard !representations.isEmpty else { return nil }
        
        super.init(entity: PasteboardItem.entity(), insertInto: context)
        
        self._representations = NSOrderedSet(array: representations)
    }
    
    override func awakeFromInsert()
    {
        super.awakeFromInsert()
        
        self.date = Date()
    }
}

extension PasteboardItem
{
    @nonobjc class func fetchRequest() -> NSFetchRequest<PasteboardItem>
    {
        return NSFetchRequest<PasteboardItem>(entityName: "PasteboardItem")
    }
}
