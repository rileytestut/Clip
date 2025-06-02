//
//  HistoryViewController.swift
//  Clip
//
//  Created by Riley Testut on 6/10/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit
import MobileCoreServices
import Combine
import CoreLocation
import Contacts

import ClipKit
import Roxas

class HistoryViewController: UITableViewController
{
    private var dataSource: RSTFetchedResultsTableViewPrefetchingDataSource<PasteboardItem, UIImage>!
    
    private let _undoManager = UndoManager()
    
    private var prototypeCell: ClippingTableViewCell!
    private var navigationBarMaskView: UIView!
    private var navigationBarGradientView: GradientView!
    
    private var didAddInitialLayoutConstraints = false
    private var cachedHeights = [NSManagedObjectID: CGFloat]()
    
    private weak var selectedItem: PasteboardItem?
    private var updateTimer: Timer?
    private var fetchLimitSettingObservation: NSKeyValueObservation?
    private var cancellables = Set<AnyCancellable>()
    
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
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.subscribe()
        
        self.extendedLayoutIncludesOpaqueBars = true
        
        self.tableView.backgroundView = self.makeGradientView()
        
        self.updateDataSource()
        
        self.tableView.contentInset.top = 8
        self.tableView.estimatedRowHeight = 0
        
        self.prototypeCell = ClippingTableViewCell.instantiate(with: ClippingTableViewCell.nib!)
        self.tableView.register(ClippingTableViewCell.nib, forCellReuseIdentifier: RSTCellContentGenericCellIdentifier)
        
        DatabaseManager.shared.persistentContainer.viewContext.undoManager = self.undoManager
        
        NotificationCenter.default.addObserver(self, selector: #selector(HistoryViewController.didEnterBackground(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(HistoryViewController.willEnterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(HistoryViewController.settingsDidChange(_:)), name: SettingsViewController.settingsDidChangeNotification, object: nil)
        
        self.fetchLimitSettingObservation = UserDefaults.shared.observe(\.historyLimit) { [weak self] (defaults, change) in
            self?.updateDataSource()
        }
        
        self.navigationBarGradientView = self.makeGradientView()
        self.navigationBarGradientView.translatesAutoresizingMaskIntoConstraints = false
        
        self.navigationBarMaskView = UIView()
        self.navigationBarMaskView.clipsToBounds = true
        self.navigationBarMaskView.translatesAutoresizingMaskIntoConstraints = false
        self.navigationBarMaskView.addSubview(self.navigationBarGradientView)
        
        if let navigationBar = self.navigationController?.navigationBar
        {
            if #available(iOS 13.0, *)
            {
                let attributes: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.white]
                
                let standardAppearance = navigationBar.standardAppearance
                standardAppearance.configureWithOpaqueBackground()
                standardAppearance.backgroundColor = .clipLightPink
                standardAppearance.titleTextAttributes = attributes
                standardAppearance.largeTitleTextAttributes = attributes
                standardAppearance.shadowImage = nil
                
                let scrollEdgeAppearance = navigationBar.scrollEdgeAppearance
                scrollEdgeAppearance?.configureWithTransparentBackground()
                scrollEdgeAppearance?.titleTextAttributes = attributes
                scrollEdgeAppearance?.largeTitleTextAttributes = attributes
            }
            else
            {
                navigationBar.shadowImage = UIImage()
                navigationBar.setBackgroundImage(nil, for: .default)
                navigationBar.insertSubview(self.navigationBarMaskView, at: 1)
            }
        }
        
        if let tabBar = self.navigationController?.tabBarController?.tabBar
        {
            let appearance = tabBar.standardAppearance
            tabBar.scrollEdgeAppearance = appearance
        }
        
        self.navigationController?.tabBarItem.image = UIImage(systemName: "list.bullet")
        
        self.startUpdating()
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
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator)
    {
        super.viewWillTransition(to: size, with: coordinator)
        
        self.cachedHeights.removeAll()
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        
        if #available(iOS 13.0, *) {}
        else
        {
            if let navigationBar = self.navigationController?.navigationBar, !self.didAddInitialLayoutConstraints
            {
                self.didAddInitialLayoutConstraints = true
                
                NSLayoutConstraint.activate([self.navigationBarGradientView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
                                             self.navigationBarGradientView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
                                             self.navigationBarGradientView.topAnchor.constraint(equalTo: self.view.topAnchor),
                                             self.navigationBarGradientView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)])
                
                NSLayoutConstraint.activate([self.navigationBarMaskView.leadingAnchor.constraint(equalTo: navigationBar.leadingAnchor),
                                             self.navigationBarMaskView.trailingAnchor.constraint(equalTo: navigationBar.trailingAnchor),
                                             self.navigationBarMaskView.topAnchor.constraint(equalTo: self.view.topAnchor),
                                             self.navigationBarMaskView.bottomAnchor.constraint(equalTo: navigationBar.bottomAnchor)])
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        guard segue.identifier == "showSettings" else { return }
        guard let sender = sender as? UIBarButtonItem else { return }
        
        let navigationController = segue.destination as! UINavigationController
        
        let settingsViewController = navigationController.viewControllers[0] as! SettingsViewController
        settingsViewController.view.layoutIfNeeded()
        
        navigationController.preferredContentSize = CGSize(width: 375, height: settingsViewController.tableView.contentSize.height)
        
        navigationController.popoverPresentationController?.delegate = self
        navigationController.popoverPresentationController?.barButtonItem = sender
    }
}

extension HistoryViewController
{
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool
    {
        let supportedActions = [#selector(UIResponderStandardEditActions.copy(_:)), #selector(UIResponderStandardEditActions.delete(_:)), #selector(HistoryViewController._share(_:))]
        
        let isSupported = supportedActions.contains(action)
        return isSupported
    }
    
    @objc override func copy(_ sender: Any?)
    {
        guard let item = self.selectedItem else { return }
        
        UIPasteboard.general.copy(item)
    }
    
    @objc override func delete(_ sender: Any?)
    {
        guard let item = self.selectedItem else { return }
        
        // Use the main view context so we can undo this operation easily.
        // Saving a context can mess with its undo history, so we only save main context when we enter background.
        item.isMarkedForDeletion = true
    }
    
    @objc func _share(_ sender: Any?)
    {
        guard let item = self.selectedItem, let indexPath = self.dataSource.fetchedResultsController.indexPath(forObject: item) else { return }
        
        let cell = self.tableView.cellForRow(at: indexPath)
        
        let activityViewController = UIActivityViewController(activityItems: [item], applicationActivities: nil)
        activityViewController.popoverPresentationController?.sourceItem = cell
        self.present(activityViewController, animated: true, completion: nil)
    }
}

private extension HistoryViewController
{
    func subscribe()
    {
        //TODO: Uncomment once we can tell user to enable location for background execution.
        //ApplicationMonitor.shared.locationManager.$status
        //    .receive(on: RunLoop.main)
        //    .compactMap { $0?.error }
        //    .sink { self.present($0) }
        //    .store(in: &self.cancellables)
    }
    
    func makeDataSource() -> RSTFetchedResultsTableViewPrefetchingDataSource<PasteboardItem, UIImage>
    {
        let fetchRequest = PasteboardItem.historyFetchRequest()
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.relationshipKeyPathsForPrefetching = [#keyPath(PasteboardItem.preferredRepresentation)]
        
        let dataSource = RSTFetchedResultsTableViewPrefetchingDataSource<PasteboardItem, UIImage>(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.persistentContainer.viewContext)
        dataSource.cellConfigurationHandler = { [weak self] (cell, item, indexPath) in
            let cell = cell as! ClippingTableViewCell
            cell.contentLabel.isHidden = false
            cell.contentImageView.isHidden = true
            
            self?.updateDate(for: cell, item: item)
            
            if let representation = item.preferredRepresentation
            {
                cell.titleLabel.text = representation.type.localizedName
                
                switch representation.type
                {
                case .text: cell.contentLabel.text = representation.stringValue
                case .attributedText: cell.contentLabel.text = representation.attributedStringValue?.string
                case .url: cell.contentLabel.text = representation.urlValue?.absoluteString
                case .image:
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
            
            if UserDefaults.shared.showLocationIcon
            {
                cell.locationButton.isHidden = (item.location == nil)
                cell.locationButton.addTarget(self, action: #selector(HistoryViewController.showLocation(_:)), for: .primaryActionTriggered)
            }
            else
            {
                cell.locationButton.isHidden = true
            }
            
            if indexPath.row < UserDefaults.shared.historyLimit.rawValue
            {
                cell.bottomConstraint.isActive = true
            }
            else
            {
                // Make it not active so we can collapse the cell to a height of 0 without auto layout errors.
                cell.bottomConstraint.isActive = false
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
        
        let placeholderView = RSTPlaceholderView()
        placeholderView.textLabel.text = NSLocalizedString("No Clippings", comment: "")
        placeholderView.textLabel.textColor = .white
        placeholderView.detailTextLabel.text = NSLocalizedString("Items that you've copied to the clipboard will appear here.", comment: "")
        placeholderView.detailTextLabel.textColor = .white
        
        let vibrancyView = UIVisualEffectView(effect: UIVibrancyEffect(blurEffect: UIBlurEffect(style: .dark)))
        vibrancyView.contentView.addSubview(placeholderView, pinningEdgesWith: .zero)
        
        let gradientView = self.makeGradientView()
        gradientView.addSubview(vibrancyView, pinningEdgesWith: .zero)
        dataSource.placeholderView = gradientView
        
        return dataSource
    }
    
    func makeGradientView() -> GradientView
    {
        let gradientView = GradientView()
        gradientView.colors = [.clipLightPink, .clipPink]
        return gradientView
    }
    
    func updateDataSource()
    {
        self.stopUpdating()
        
        self.dataSource = self.makeDataSource()
        self.tableView.dataSource = self.dataSource
        self.tableView.prefetchDataSource = self.dataSource
        self.tableView.reloadData()
        
        self.startUpdating()
    }
    
    func updateDate(for cell: ClippingTableViewCell, item: PasteboardItem)
    {
        if Date().timeIntervalSince(item.date) < 2
        {
            cell.dateLabel.text = NSLocalizedString("now", comment: "")
        }
        else
        {
            cell.dateLabel.text = self.dateComponentsFormatter.string(from: item.date, to: Date())
        }
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
    
    @objc func showLocation(_ sender: UIButton)
    {
        let point = self.view.convert(sender.center, from: sender.superview!)
        guard let indexPath = self.tableView.indexPathForRow(at: point) else { return }
        
        let item = self.dataSource.item(at: indexPath)
        guard let location = item.location else { return }
        
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { (placemarks, error) in
            DispatchQueue.main.async {
                let title: String
                let message: String?
                
                if let placemarks, let placemark = placemarks.first,
                   let postalAddress = placemark.postalAddress?.mutableCopy() as? CNMutablePostalAddress
                {
                    // The location isn't precise, so don't pretend that it is by showing street address.
                    postalAddress.street = ""
                    postalAddress.subLocality = ""
                    
                    let formatter = CNPostalAddressFormatter()
                    
                    if let sublocality = placemark.subLocality
                    {
                        title = sublocality + "\n" + formatter.string(from: postalAddress)
                    }
                    else
                    {
                        title = formatter.string(from: postalAddress)
                    }

                    message = nil
                }
                else if let error
                {
                    title = NSLocalizedString("Unable to Look Up Location", comment: "")
                    message = error.localizedDescription + "\n\n" + "\(location.coordinate.latitude), \(location.coordinate.longitude)"
                }
                else
                {
                    title = "\(location.coordinate.latitude), \(location.coordinate.longitude)"
                    message = nil
                }
                
                let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
                alertController.addAction(.ok)
                self.present(alertController, animated: true)
            }
        }
    }
    
    func startUpdating()
    {
        self.stopUpdating()
        
        self.updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] (timer) in
            guard let self = self else { return }
            
            for indexPath in self.tableView.indexPathsForVisibleRows ?? []
            {
                guard let cell = self.tableView.cellForRow(at: indexPath) as? ClippingTableViewCell else { continue }
                
                let item = self.dataSource.item(at: indexPath)
                self.updateDate(for: cell, item: item)
            }
        }
    }
    
    func stopUpdating()
    {
        self.updateTimer?.invalidate()
        self.updateTimer = nil
    }
}

private extension HistoryViewController
{
    func present(_ error: Error)
    {
        let nsError = error as NSError
        
        let alertController = UIAlertController(title: nsError.localizedFailureReason ?? nsError.localizedDescription,
                                                message: nsError.localizedRecoverySuggestion, preferredStyle: .alert)
        
        if let recoverableError = error as? RecoverableError, !recoverableError.recoveryOptions.isEmpty
        {
            alertController.addAction(.cancel)
            
            for (index, title) in zip(0..., recoverableError.recoveryOptions)
            {
                let action = UIAlertAction(title: title, style: .default) { (action) in
                    recoverableError.attemptRecovery(optionIndex: index) { (success) in
                        print("Recovered from error with success:", success)
                    }
                }
                alertController.addAction(action)
            }
        }
        else
        {
            alertController.addAction(.ok)
        }
        
        self.present(alertController, animated: true, completion: nil)
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
        
        self.stopUpdating()
    }
    
    @objc func willEnterForeground(_ notification: Notification)
    {
        self.startUpdating()
    }
    
    @objc func settingsDidChange(_ notification: Notification)
    {
        self.tableView.reloadData()
    }
    
    @IBAction func unwindToHistoryViewController(_ segue: UIStoryboardSegue)
    {
    }
}

extension HistoryViewController
{
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        // It's far *far* easier to simply set row height to 0 for cells beyond history limit
        // than to actually limit fetched results to the correct number live (with insertions and deletions).
        guard indexPath.row < UserDefaults.shared.historyLimit.rawValue else { return 0.0 }
        
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

extension HistoryViewController: UIPopoverPresentationControllerDelegate
{
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle
    {
        return .none
    }
}
