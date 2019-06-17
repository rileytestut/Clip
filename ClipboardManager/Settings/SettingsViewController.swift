//
//  SettingsViewController.swift
//  ClipboardManager
//
//  Created by Riley Testut on 6/14/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit

import ClipKit

extension SettingsViewController
{
    private enum Section: CaseIterable
    {
        case maximumClippingSize
        case historyLimit
    }
}

class SettingsViewController: UITableViewController
{
    @IBOutlet private var clippingSizeSlider: UISlider!
    @IBOutlet private var clippingSizeLabel: UILabel!
    
    private var supportedClippingSizeRange: ClosedRange<Int> {
        // Audio Unit extension memory limit is around ~360MB
        // https://forum.juce.com/t/multiple-auv3-instances-on-ipad-pro-problem/23747/12
        // This range is in MB because the UI is in MB, but we store it as bytes in UserDefaults.
        return 1...300
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.update()
    }
}

private extension SettingsViewController
{
    func update()
    {
        let range = self.supportedClippingSizeRange.upperBound - self.supportedClippingSizeRange.lowerBound
        
        let maximumClippingSize = UserDefaults.shared.maximumClippingSize / .bytesPerMegabyte
        let value = Float(maximumClippingSize - self.supportedClippingSizeRange.lowerBound) / Float(range)
        self.clippingSizeSlider.value = value
            
        self.clippingSizeLabel.text = String(format: NSLocalizedString("%@ MB", comment: ""), NSNumber(value: maximumClippingSize))
    }
}

private extension SettingsViewController
{
    @IBAction func changeClippingLimit(_ sender: UISlider)
    {
        let range = self.supportedClippingSizeRange.upperBound - self.supportedClippingSizeRange.lowerBound
        
        var value = Int((Float(range) * sender.value).rounded())
        value += self.supportedClippingSizeRange.lowerBound
        UserDefaults.shared.maximumClippingSize = value * .bytesPerMegabyte
        
        self.update()
    }
}

extension SettingsViewController
{
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        
        switch Section.allCases[indexPath.section]
        {
        case .maximumClippingSize: break
        case .historyLimit:
            let limit = HistoryLimit.allCases[indexPath.row]
            cell.accessoryType = (limit == UserDefaults.shared.historyLimit) ? .checkmark : .none
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        guard Section.allCases[indexPath.section] == .historyLimit else { return }
        
        let historyLimit = HistoryLimit.allCases[indexPath.row]
        UserDefaults.shared.historyLimit = historyLimit
        
        tableView.reloadData()
    }
}
