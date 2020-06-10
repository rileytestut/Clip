//
//  Preview.swift
//  ClipKit
//
//  Created by Riley Testut on 5/26/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

struct Preview
{
    static func prepare()
    {
        if DatabaseManager.shared.persistentContainer.persistentStoreCoordinator.persistentStores.isEmpty
        {
            let inMemoryStoreDescription = NSPersistentStoreDescription()
            inMemoryStoreDescription.type = NSInMemoryStoreType
            
            DatabaseManager.shared.persistentContainer.persistentStoreDescriptions = [inMemoryStoreDescription]
            DatabaseManager.shared.persistentContainer.shouldAddStoresAsynchronously = false
            DatabaseManager.shared.prepare() { (result) in
                print("Database Result:", result)
            }
        }
        
        // Manually call initialize() since it isn't normally called when previewing 🤷‍♂️
        UserDefaults.initialize()
    }
}
