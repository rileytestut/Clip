//
//  KeyboardViewController.swift
//  ClipBoard
//
//  Created by Riley Testut on 5/25/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import UIKit
import SwiftUI
import Roxas

import ClipKit

class KeyboardViewController: UIInputViewController
{
    private var hostingViewController: UIHostingController<AnyView>!
    private var heightConstraint: NSLayoutConstraint!
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?)
    {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        
        if DatabaseManager.shared.persistentContainer.persistentStoreCoordinator.persistentStores.isEmpty
        {
            DatabaseManager.shared.persistentContainer.shouldAddStoresAsynchronously = false
            DatabaseManager.shared.prepare { (result) in
                switch result
                {
                case .failure(let error): print("Failed to prepare database:", error)
                case .success: break
                }
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.inputView?.allowsSelfSizing = true
        
        let rootView = Keyboard(inputViewController: self)
            .environment(\.managedObjectContext, DatabaseManager.shared.persistentContainer.viewContext)
        
        self.hostingViewController = UIHostingController(rootView: AnyView(rootView))
        self.hostingViewController.view.backgroundColor = .clear
        
        self.addChild(self.hostingViewController)
        self.inputView?.addSubview(self.hostingViewController.view, pinningEdgesWith: .zero)
        self.hostingViewController.didMove(toParent: self)
        
        self.view.setNeedsUpdateConstraints()
    }

    override func updateViewConstraints()
    {
        super.updateViewConstraints()
                
        if self.heightConstraint == nil
        {
            for constraint in self.view.constraintsAffectingLayout(for: .vertical)
            {
                // UIKit embeds height constraint, even if allowsSelfSizing is true.
                // Must set to non-required priority, or else it will conflict with
                // our own self-sizing constraint (annoyingly).
                constraint.priority = .defaultHigh
            }
            
            self.heightConstraint = self.view.heightAnchor.constraint(equalToConstant: UIScreen.main.bounds.height / 2)
            self.heightConstraint.isActive = true
        }
    }
    
    override func viewWillLayoutSubviews()
    {
        if let heightConstraint = self.heightConstraint
        {
            heightConstraint.constant = UIScreen.main.bounds.height / 2
        }
        
        super.viewWillLayoutSubviews()
    }
}
