//
//  DatabaseManager.swift
//  ClipboardManager
//
//  Created by Riley Testut on 6/11/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import CoreData

import Roxas

class DatabaseManager
{
    static let shared = DatabaseManager()
    
    let persistentContainer = RSTPersistentContainer(name: "Model")
    
    private init()
    {
    }
    
    func prepare()
    {
        self.persistentContainer.loadPersistentStores { (description, error) in
        }
    }
}
