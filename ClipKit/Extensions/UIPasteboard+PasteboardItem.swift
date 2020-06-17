//
//  UIPasteboard+PasteboardItem.swift
//  ClipKit
//
//  Created by Riley Testut on 5/26/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import UIKit

public extension UIPasteboard
{
    func copy(_ pasteboardItem: PasteboardItem)
    {
        var representations = pasteboardItem.representations.reduce(into: [:]) { $0[$1.uti] = $1.pasteboardValue }
        representations[UTI.clipping] = [:]
        
        self.setItems([representations], options: [:])
    }
}
