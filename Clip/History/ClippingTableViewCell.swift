//
//  ClippingTableViewCell.swift
//  Clip
//
//  Created by Riley Testut on 6/13/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit

@objc(ClippingTableViewCell)
class ClippingTableViewCell: UITableViewCell
{
    @IBOutlet var clippingView: UIView!
    
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var dateLabel: UILabel!
    @IBOutlet var contentLabel: UILabel!
    @IBOutlet var contentImageView: UIImageView!
    
    @IBOutlet var bottomConstraint: NSLayoutConstraint!
    
    override func awakeFromNib()
    {
        super.awakeFromNib()
        
        self.clippingView.layer.cornerRadius = 10
        self.clippingView.layer.masksToBounds = true
        
        self.contentImageView.layer.cornerRadius = 10
        self.contentImageView.layer.masksToBounds = true
    }
}
