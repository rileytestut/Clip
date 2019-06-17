//
//  HistoryViewController.swift
//  ClipboardManager
//
//  Created by Riley Testut on 6/10/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit
import MobileCoreServices

import ClipKit
import Roxas

class HistoryViewController: UITableViewController
{
    private lazy var dataSource = self.makeDataSource()
    
    private var prototypeCell: ClippingTableViewCell!
    private var cachedHeights = [NSManagedObjectID: CGFloat]()
    
    private weak var selectedItem: PasteboardItem?
    
    private let _undoManager = UndoManager()
    
    private lazy var dateComponentsFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 1
        formatter.allowedUnits = [.second, .minute, .hour, .day]
        return formatter
    }()
    
    override var undoManager: UndoManager? {
        return _undoManager
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.tableView.dataSource = self.dataSource
        self.tableView.prefetchDataSource = self.dataSource
        
        self.tableView.contentInset.top = 8
        self.tableView.estimatedRowHeight = 0
        
        self.prototypeCell = ClippingTableViewCell.instantiate(with: ClippingTableViewCell.nib!)
        self.tableView.register(ClippingTableViewCell.nib, forCellReuseIdentifier: RSTCellContentGenericCellIdentifier)
        
        DatabaseManager.shared.persistentContainer.viewContext.undoManager = self.undoManager
        
        NotificationCenter.default.addObserver(self, selector: #selector(HistoryViewController.didEnterBackground(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        
        self.becomeFirstResponder()
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
        
        self.resignFirstResponder()
    }
    
    override var canBecomeFirstResponder: Bool
    {
        return true
    }
}

extension HistoryViewController
{
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool
    {
        let supportedActions = [#selector(UIResponderStandardEditActions.copy(_:)), #selector(UIResponderStandardEditActions.delete(_:))]
        
        let isSupported = supportedActions.contains(action)
        return isSupported
    }
    
    @objc override func copy(_ sender: Any?)
    {
        guard let item = self.selectedItem else { return }
        
        PasteboardMonitor.shared.copy(item)
    }
    
    @objc override func delete(_ sender: Any?)
    {
        guard let item = self.selectedItem else { return }
        
        // Use the main view context so we can undo this operation easily.
        // Saving a context can mess with its undo history, so we only save main context when we enter background.
        item.isMarkedForDeletion = true
    }
}

private extension HistoryViewController
{
    func makeDataSource() -> RSTFetchedResultsTableViewPrefetchingDataSource<PasteboardItem, UIImage>
    {
        let fetchRequest = PasteboardItem.fetchRequest() as NSFetchRequest<PasteboardItem>
        fetchRequest.predicate = NSPredicate(format: "%K == NO", #keyPath(PasteboardItem.isMarkedForDeletion))
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \PasteboardItem.date, ascending: false)]
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.relationshipKeyPathsForPrefetching = [#keyPath(PasteboardItem.preferredRepresentation)]
        
        let dataSource = RSTFetchedResultsTableViewPrefetchingDataSource<PasteboardItem, UIImage>(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.persistentContainer.viewContext)
        dataSource.cellConfigurationHandler = { (cell, item, indexPath) in
            let cell = cell as! ClippingTableViewCell
            cell.contentLabel.isHidden = false
            cell.contentImageView.isHidden = true
            
            if Date().timeIntervalSince(item.date) < 5
            {
                cell.dateLabel.text = NSLocalizedString("now", comment: "")
            }
            else
            {
                cell.dateLabel.text = self.dateComponentsFormatter.string(from: item.date, to: Date())
            }
            
            if let representation = item.preferredRepresentation
            {
                switch representation.type
                {
                case .text:
                    cell.titleLabel.text = NSLocalizedString("Text", comment: "")
                    cell.contentLabel.text = representation.stringValue
                    
                case .attributedText:
                    cell.titleLabel.text = NSLocalizedString("Text", comment: "")
                    cell.contentLabel.text = representation.attributedStringValue?.string
                    
                case .url:
                    cell.titleLabel.text = NSLocalizedString("URL", comment: "")
                    cell.contentLabel.text = representation.urlValue?.absoluteString
                    
                case .image:
                    cell.titleLabel.text = NSLocalizedString("Image", comment: "")
                    cell.contentLabel.isHidden = true
                    cell.contentImageView.isHidden = false
                    cell.contentImageView.isIndicatingActivity = true
                }
            }
            else
            {
                cell.titleLabel.text = NSLocalizedString("Unknown", comment: "")
                cell.contentLabel.isHidden = true
            }
        }
        
        dataSource.prefetchHandler = { (item, indexPath, completionHandler) in
            guard let representation = item.preferredRepresentation, representation.type == .image else { return nil }
            
            return RSTBlockOperation() { (operation) in
                guard let image = representation.imageValue?.resizing(toFill: CGSize(width: 500, height: 500)) else { return completionHandler(nil, nil) }
                completionHandler(image, nil)
            }
        }
        
        dataSource.prefetchCompletionHandler = { (cell, image, indexPath, error) in
            DispatchQueue.main.async {
                let cell = cell as! ClippingTableViewCell

                if let image = image
                {
                    cell.contentImageView.image = image
                }
                else
                {
                    cell.contentImageView.image = nil
                }

                cell.contentImageView.isIndicatingActivity = false
            }
        }
        
        return dataSource
    }
    
    func showMenu(at indexPath: IndexPath)
    {
        guard let cell = self.tableView.cellForRow(at: indexPath) as? ClippingTableViewCell else { return }
        
        let item = self.dataSource.item(at: indexPath)
        self.selectedItem = item
        
        let targetRect = cell.clippingView.frame
        
        self.becomeFirstResponder()
        
        UIMenuController.shared.setTargetRect(targetRect, in: cell)
        UIMenuController.shared.setMenuVisible(true, animated: true)
    }
}

private extension HistoryViewController
{
    @objc func didEnterBackground(_ notification: Notification)
    {
        // Save any pending changes to disk.
        if DatabaseManager.shared.persistentContainer.viewContext.hasChanges
        {
            do
            {
                try DatabaseManager.shared.persistentContainer.viewContext.save()
            }
            catch
            {
                print("Failed to save view context.", error)
            }
        }
        
        self.undoManager?.removeAllActions()
    }
}

extension HistoryViewController
{
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        let item = self.dataSource.item(at: indexPath)
        
        if let height = self.cachedHeights[item.objectID]
        {
            return height
        }
        
        let portraitScreenHeight = UIScreen.main.coordinateSpace.convert(UIScreen.main.bounds, to: UIScreen.main.fixedCoordinateSpace).height
        let maximumHeight: CGFloat
        
        if item.preferredRepresentation?.type == .image
        {
            maximumHeight = portraitScreenHeight / 2
        }
        else
        {
            maximumHeight = portraitScreenHeight / 3
        }
        
        let widthConstraint = self.prototypeCell.contentView.widthAnchor.constraint(equalToConstant: tableView.bounds.width)
        let heightConstraint = self.prototypeCell.contentView.heightAnchor.constraint(lessThanOrEqualToConstant: maximumHeight)
        NSLayoutConstraint.activate([widthConstraint, heightConstraint])
        defer { NSLayoutConstraint.deactivate([widthConstraint, heightConstraint]) }
        
        self.dataSource.cellConfigurationHandler(self.prototypeCell, item, indexPath)
        
        let size = self.prototypeCell.contentView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        self.cachedHeights[item.objectID] = size.height
        return size.height
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        self.showMenu(at: indexPath)
    }
}

