//
//  DatabaseManager.swift
//  Clip
//
//  Created by Riley Testut on 6/11/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import CoreData

import Roxas

private extension UserDefaults
{
    @NSManaged var previousHistoryToken: Data?
}

public enum PasteboardError: LocalizedError
{
    case unsupportedImageFormat
    case unsupportedItem
    case noItem
    case duplicateItem
    
    public var errorDescription: String? {
        switch self
        {
        case .unsupportedImageFormat: return NSLocalizedString("Unsupported image format.", comment: "")
        case .unsupportedItem: return NSLocalizedString("Unsupported clipboard item.", comment: "")
        case .noItem: return NSLocalizedString("No clipboard item.", comment: "")
        case .duplicateItem: return NSLocalizedString("Duplicate item.", comment: "")
        }
    }
}

private class PersistentContainer: RSTPersistentContainer
{
    override class func defaultDirectoryURL() -> URL
    {
        guard let appGroup = Bundle.main.appGroups.first else { return super.defaultDirectoryURL() }
        
        let sharedDirectoryURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)!
        
        let databaseDirectoryURL = sharedDirectoryURL.appendingPathComponent("Database")
        try? FileManager.default.createDirectory(at: databaseDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        
        print("Database URL:", databaseDirectoryURL)
        return databaseDirectoryURL
    }
}

public class DatabaseManager
{
    public static let shared = DatabaseManager()
    
    public let persistentContainer: RSTPersistentContainer = PersistentContainer(name: "Model", bundle: Bundle(for: DatabaseManager.self))
    
    public private(set) var isStarted = false
    
    private var prepareCompletionHandlers = [(Result<Void, Error>) -> Void]()
    private let dispatchQueue = DispatchQueue(label: "com.rileytestut.Clip.DatabaseManager")
    
    private var previousHistoryToken: NSPersistentHistoryToken? {
        set {
            guard let value = newValue else {
                UserDefaults.shared.previousHistoryToken = nil
                return
            }
            
            let data = try? NSKeyedArchiver.archivedData(withRootObject: value, requiringSecureCoding: true)
            UserDefaults.shared.previousHistoryToken = data
        }
        get {
            guard let data = UserDefaults.shared.previousHistoryToken else { return nil }
            
            let token = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSPersistentHistoryToken.self, from: data)
            return token
        }
    }
    
    private init()
    {
    }
    
    public func prepare(completionHandler: @escaping (Result<Void, Error>) -> Void)
    {
        func finish(_ result: Result<Void, Error>)
        {
            self.dispatchQueue.async {
                switch result
                {
                case .success: self.isStarted = true
                case .failure: break
                }
                
                self.prepareCompletionHandlers.forEach { $0(result) }
                self.prepareCompletionHandlers.removeAll()
            }
        }
        
        self.dispatchQueue.async {
            self.prepareCompletionHandlers.append(completionHandler)
            guard self.prepareCompletionHandlers.count == 1 else { return }
            
            guard !self.isStarted else { return finish(.success(())) }
            
            self.persistentContainer.persistentStoreDescriptions.first?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            
            self.persistentContainer.loadPersistentStores { (description, error) in
                let result = Result(description, error).map { _ in () }
                finish(result)
                
                self.purge()
            }
        }
    }
    
    public func refresh()
    {
        DatabaseManager.shared.persistentContainer.performBackgroundTask { (context) in
            let fetchRequest = NSPersistentHistoryChangeRequest.fetchHistory(after: self.previousHistoryToken)
            
            do
            {
                guard
                    let result = try context.execute(fetchRequest) as? NSPersistentHistoryResult,
                    let transactions = result.result as? [NSPersistentHistoryTransaction]
                else { return }
                
                DispatchQueue.main.async {
                    
                    self.persistentContainer.viewContext.undoManager?.disableUndoRegistration()
                    defer { self.persistentContainer.viewContext.undoManager?.enableUndoRegistration() }
                    
                    for transaction in transactions
                    {
                        self.persistentContainer.viewContext.mergeChanges(fromContextDidSave: transaction.objectIDNotification())
                    }
                    
                    if let token = transactions.last?.token
                    {
                        self.previousHistoryToken = token
                    }
                }
            }
            catch let error as CocoaError where error.code.rawValue == NSPersistentHistoryTokenExpiredError
            {
                self.previousHistoryToken = nil
                self.refresh()
            }
            catch
            {
                print("Failed to fetch change history.", error)
            }
        }
    }
    
    public func purge()
    {
        // In-memory contexts don't support history tracking.
        guard let description = DatabaseManager.shared.persistentContainer.persistentStoreDescriptions.first, description.type != NSInMemoryStoreType else { return }
        
        DatabaseManager.shared.persistentContainer.performBackgroundTask { (context) in
            if let token = self.previousHistoryToken
            {
                let deleteHistoryRequest = NSPersistentHistoryChangeRequest.deleteHistory(before: token)
                
                do { try context.execute(deleteHistoryRequest) }
                catch { print("Failed to delete persistent distory.", error) }
            }
            
            do
            {
                let fetchRequest = PasteboardItem.historyFetchRequest() as! NSFetchRequest<NSManagedObjectID>
                fetchRequest.resultType = .managedObjectIDResultType
                
                let objectIDs = try context.fetch(fetchRequest)
                
                let deletionFetchRequest = PasteboardItem.fetchRequest() as NSFetchRequest<NSFetchRequestResult>
                deletionFetchRequest.predicate = NSPredicate(format: "NOT (SELF IN %@)", objectIDs)
                
                let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: deletionFetchRequest)
                batchDeleteRequest.resultType = .resultTypeObjectIDs
                
                guard
                    let result = try context.execute(batchDeleteRequest) as? NSBatchDeleteResult,
                    let deletedObjectIDs = result.result as? [NSManagedObjectID]
                else { return }
                
                let changes = [NSDeletedObjectsKey: deletedObjectIDs]
                
                DispatchQueue.main.async {
                    NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [DatabaseManager.shared.persistentContainer.viewContext])
                }
            }
            catch
            {
                print("Failed to delete pasteboard items.", error)
            }
        }
    }
}

public extension DatabaseManager
{
    func savePasteboard(completionHandler: @escaping (Result<Void, Error>) -> Void)
    {
        do
        {
            guard !UIPasteboard.general.hasColors else {
                throw PasteboardError.unsupportedItem // Accessing UIPasteboard.items causes crash as of iOS 12.3 if it contains a UIColor.
            }
            
            print("Did update pasteboard!")
            
            guard let itemProvider = UIPasteboard.general.itemProviders.first else { throw PasteboardError.noItem }
            guard !itemProvider.registeredTypeIdentifiers.contains(UTI.clipping) else { throw PasteboardError.duplicateItem } // Ignore copies that we made from the app.
            
            let context = DatabaseManager.shared.persistentContainer.newBackgroundContext()
            PasteboardItemRepresentation.representations(for: itemProvider, in: context) { (representations) in
                do
                {
                    guard let pasteboardItem = PasteboardItem(representations: representations, context: context) else { throw PasteboardError.noItem }
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
                            throw PasteboardError.duplicateItem
                        }
                    }
                    
                    guard let _ = pasteboardItem.preferredRepresentation else { throw PasteboardError.unsupportedItem }
                    
                    context.transactionAuthor = Bundle.main.bundleIdentifier
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
