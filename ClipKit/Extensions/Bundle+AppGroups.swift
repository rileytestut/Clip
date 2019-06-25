//
//  Bundle+AppGroups.swift
//  ClipKit
//
//  Created by Riley Testut on 6/25/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Foundation

public extension Bundle
{
    var appGroups: [String] {
        let appGroups = self.object(forInfoDictionaryKey: "ALTAppGroups") as? [String]
        return appGroups ?? []
    }
}
