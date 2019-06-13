//
//  String+OSType.swift
//  ClipKit
//
//  Created by Riley Testut on 6/13/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Foundation

internal extension String
{
    /// Converts 4-character strings to their OSType representation.
    var osType: OSType {
        assert(self.count == 4, "String must have exactly 4 characters to convert to OSType.")
        
        var osType: OSType = 0
        
        for (index, character) in self.enumerated()
        {
            let shift = (self.count - index - 1) * Int8.bitWidth
            osType |= (UInt32(character.asciiValue!) << shift)
        }
        
        return osType
    }
}
