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
                UserDefaults.standard.previousHistoryToken = nil
                return
            }
            
            let data = try? NSKeyedArchiver.archivedData(withRootObject: value, requiringSecureCoding: true)
            UserDefaults.standard.previousHistoryToken = data
        }
        get {
            guard let data = UserDefaults.standard.previousHistoryToken else { return nil }
            
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
                    for transaction in transactions
                    {
                        self.persistentContainer.viewContext.mergeChanges(fromContextDidSave: transaction.objectIDNotification())
                    }
                    
                    if let token = transactions.last?.token
                    {
                        self.previousHistoryToken = token
                        self.purgeHistory(before: token)
                    }
                }
            }
            catch
            {
                print("Failed to fetch change history.", error)
            }
        }
        
    }
}

private extension DatabaseManager
{
    func purgeHistory(before token: NSPersistentHistoryToken)
    {
        DatabaseManager.shared.persistentContainer.performBackgroundTask { (context) in
            let deleteHistoryRequest = NSPersistentHistoryChangeRequest.deleteHistory(before: token)
            
            do { try context.execute(deleteHistoryRequest) }
            catch { print("Failed to delete persistent distory.", error) }
        }
    }
}
