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

@objc(ImageClipboardCell)
private class ImageClipboardCell: UITableViewCell
{
    @IBOutlet var thumbnailImageView: UIImageView!
}

class HistoryViewController: UITableViewController
{
    private lazy var dataSource = self.makeDataSource()
    
    override func viewDidLoad()
    {
        super.viewDidLoad()

        self.tableView.dataSource = self.dataSource
        self.tableView.prefetchDataSource = self.dataSource        
    }
}

private extension HistoryViewController
{
    func makeDataSource() -> RSTFetchedResultsTableViewPrefetchingDataSource<PasteboardItem, UIImage>
    {
        let fetchRequest = PasteboardItem.fetchRequest() as NSFetchRequest<PasteboardItem>
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \PasteboardItem.date, ascending: false)]
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.relationshipKeyPathsForPrefetching = ["representations"]
        
        let dataSource = RSTFetchedResultsTableViewPrefetchingDataSource<PasteboardItem, UIImage>(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.persistentContainer.viewContext)
        dataSource.cellIdentifierHandler = { [unowned dataSource] (indexPath) in
            let item = dataSource.item(at: indexPath)
            
            if let _ = item.representations.first(where: { UTTypeConformsTo($0.uti as CFString, kUTTypeImage) })
            {
                return "ImageCell"
            }
            else
            {
                return RSTCellContentGenericCellIdentifier
            }
        }
        dataSource.cellConfigurationHandler = { (cell, item, indexPath) in
            cell.imageView?.image = nil
            
            if let _ = item.representations.first(where: { UTTypeConformsTo($0.uti as CFString, kUTTypeImage) })
            {
                let cell = cell as! ImageClipboardCell
                cell.thumbnailImageView.isIndicatingActivity = true
                cell.thumbnailImageView.contentMode = .scaleAspectFill
                cell.thumbnailImageView.clipsToBounds = true
            }
            else if let representation = item.representations.first(where: { UTTypeConformsTo($0.uti as CFString, kUTTypePlainText) })
            {
                cell.textLabel?.text = representation.stringValue
                cell.textLabel?.textColor = .darkText
            }
            else if let representation = item.representations.first(where: { UTTypeConformsTo($0.uti as CFString, kUTTypeURL) })
            {
                cell.textLabel?.text = representation.urlValue?.absoluteString
                cell.textLabel?.textColor = .blue
            }
            else
            {
                cell.textLabel?.text = NSLocalizedString("[Unknown Type]", comment: "")
                cell.textLabel?.textColor = .gray
            }
        }
        
        dataSource.prefetchHandler = { (item, indexPath, completionHandler) in
            guard let representation = item.representations.first(where: { UTTypeConformsTo($0.uti as CFString, kUTTypeImage) }) else { return nil }
            
            return RSTBlockOperation() { (operation) in
                guard let image = representation.imageValue?.resizing(toFill: CGSize(width: 300, height: 300)) else { return completionHandler(nil, nil) }
                completionHandler(image, nil)
            }
        }
        
        dataSource.prefetchCompletionHandler = { (cell, image, indexPath, error) in
            DispatchQueue.main.async {
                let cell = cell as! ImageClipboardCell
                
                if let image = image
                {
                    cell.thumbnailImageView.image = image
                }
                else
                {
                    cell.thumbnailImageView.image = nil
                }
                
                cell.thumbnailImageView.isIndicatingActivity = false
            }
        }
        
        return dataSource
    }
}

