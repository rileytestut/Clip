//
//  GradientView.swift
//  Clip
//
//  Created by Riley Testut on 7/27/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit

class GradientView: UIView
{
    var colors: [UIColor] = [] {
        didSet {
            self.gradientLayer.colors = self.colors.map { $0.cgColor }
        }
    }
    override class var layerClass: AnyClass {
        return CAGradientLayer.self
    }
    
    private var gradientLayer: CAGradientLayer {
        return self.layer as! CAGradientLayer
    }
    
    override init(frame: CGRect)
    {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
