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
        case historyLimit
    }
}

class SettingsViewController: UITableViewController
{
}

extension SettingsViewController
{
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        
        switch Section.allCases[indexPath.section]
        {
        case .historyLimit:
            let limit = HistoryLimit.allCases[indexPath.row]
            cell.accessoryType = (limit == UserDefaults.standard.historyLimit) ? .checkmark : .none
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        guard Section.allCases[indexPath.section] == .historyLimit else { return }
        
        let historyLimit = HistoryLimit.allCases[indexPath.row]
        UserDefaults.standard.historyLimit = historyLimit
        
        tableView.reloadData()
    }
}
