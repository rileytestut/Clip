//
//  DatabaseManager.swift
//  ClipboardManager
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

private class PersistentContainer: RSTPersistentContainer
{
    override class func defaultDirectoryURL() -> URL
    {
        let sharedDirectoryURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.rileytestut.ClipboardManager")!
        
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
        self.persistentContainer.persistentStoreDescriptions.first?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        
        self.persistentContainer.loadPersistentStores { (description, error) in            
            let result = Result(description, error).map { _ in () }
            completionHandler(result)
            
            self.purge()
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
