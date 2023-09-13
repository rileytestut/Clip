//
//  ClippingEntity.swift
//  Clip
//
//  Created by Riley Testut on 9/11/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import AppIntents
import CoreData
import UniformTypeIdentifiers

@preconcurrency import ClipKit

@available(iOS 16, *)
struct ClippingEntity: AppEntity, Identifiable
{
    static var defaultQuery = Query()
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Clipping", numericFormat: "Clippings")
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(self.text2 ?? "(Image)")",
//                              subtitle: "\(self.date.formatted())",
                              image: self.displayImage)
    }
    
//    var name: LocalizedStringResource {
//        return self.text ?? "(Image)"
//    }
    
    var id: String
    
    @Property(title: "Date")
    var date: Date
    
    @Property(title: "Text")
    var text2: String?
    
    @Property(title: "Clipboard Data")
    var data: IntentFile
    
//    var data: Data
//    var type: PasteboardItemRepresentation.RepresentationType
    
    private(set) var pasteboardItem: PasteboardItem
    private var displayImage: DisplayRepresentation.Image?
}

@available(iOS 16, *)
extension ClippingEntity
{
    init?(_ pasteboardItem: PasteboardItem)
    {
        guard let representation = pasteboardItem.preferredRepresentation ?? pasteboardItem.representations.first, let data = representation.rawPasteboardValue else { return nil }
        
        self.pasteboardItem = pasteboardItem
        
        self.id = pasteboardItem.objectID.uriRepresentation().absoluteString
        
        var type = UTType(representation.uti)
        if representation.type == .url
        {
            type = .utf8PlainText
        }
        
        var file = IntentFile(data: data, filename: "Clipping", type: type)
        file.removedOnCompletion = true
        self.data = file
        
//        self.data = representation.dataValue ?? Data()
//        self.type = representation.type
        self.date = pasteboardItem.date
        self.text2 = representation.stringValue
                
        if let image = representation.imageValue,
           let resizedImage = image.resizing(toFit: CGSize(width: 250, height: 250)),
           let roundedImage = resizedImage.withCornerRadius(12),
           let pngData = roundedImage.pngData()
        {
            self.displayImage = DisplayRepresentation.Image(data: pngData)
        }
    }
}

@available(iOS 16, *)
extension ClippingEntity
{
    struct Query: EntityQuery, EntityStringQuery
    {
//        func defaultResult() async -> DefaultValue? 
//        {
//            return try await self.suggestedEntities()
//        }
        
        @MainActor
        func entities(for identifiers: [String]) async throws -> [ClippingEntity]
        {
//            try DatabaseManager.shared.prepare
            
            let pasteboardItems = identifiers.compactMap { (identifier) -> PasteboardItem? in
                guard let uri = URL(string: identifier), let objectID = DatabaseManager.shared.persistentContainer.viewContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: uri) else { return nil }
                
                let pasteboardItem = DatabaseManager.shared.persistentContainer.viewContext.object(with: objectID) as? PasteboardItem
                return pasteboardItem
            }
            
            let clippings = pasteboardItems.compactMap { ClippingEntity($0) }
            return clippings
        }
        
        @MainActor
        // Creates parameterized shortcuts
        func suggestedEntities() async throws -> [ClippingEntity]
        {
            let fetchRequest = PasteboardItem.fetchRequest() as NSFetchRequest<PasteboardItem>
            fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \PasteboardItem.date, ascending: false)]
//                fetchRequest.fetchLimit = 10
            
            let pasteboardItems = try DatabaseManager.shared.persistentContainer.viewContext.fetch(fetchRequest)
            let clippings = pasteboardItems.compactMap(ClippingEntity.init(_:))
            return clippings
        }
        
        func entities(matching string: String) async throws -> [ClippingEntity] 
        {
            let context = DatabaseManager.shared.persistentContainer.newBackgroundContext()
            return try await context.perform {
                let fetchRequest = PasteboardItem.fetchRequest() as NSFetchRequest<PasteboardItem>
                fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \PasteboardItem.date, ascending: false)]
                
                let pasteboardItems = try context.fetch(fetchRequest)
                
                let predicate = NSPredicate(forSearchingForText: string, inValuesForKeyPaths: [#keyPath(PasteboardItem.preferredRepresentation.stringValue)])
                let filteredItems = (pasteboardItems as NSArray).filtered(using: predicate) as! [PasteboardItem]
                
                let clippings = filteredItems.compactMap(ClippingEntity.init(_:))
                return clippings
            }
        }
    }
}
