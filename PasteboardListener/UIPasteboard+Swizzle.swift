//
//  UIPasteboard+Swizzle.swift
//  PasteboardListener
//
//  Created by Riley Testut on 9/27/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Foundation
import ObjectiveC.runtime

extension Bundle
{
    @objc private var swizzled_infoDictionary: [String : Any]? {
        var infoDictionary = self.swizzled_infoDictionary
        
        infoDictionary?[kCFBundleIdentifierKey as String] = "com.rileytestut.Clip.PasteboardListener.AlwaysOn"
        
        return infoDictionary
    }
    
    @objc private func swizzled_object(forInfoDictionaryKey key: String) -> Any?
    {
        let object = self.swizzled_object(forInfoDictionaryKey: key)
        return object
    }
    
    public static func swizzleBundleID(handler: () -> Void)
    {
        let bundleClass: AnyClass = Bundle.self
        
        guard
            let originalMethod = class_getInstanceMethod(bundleClass, #selector(Bundle.object(forInfoDictionaryKey:))),
            let swizzledMethod = class_getInstanceMethod(bundleClass, #selector(Bundle.swizzled_object(forInfoDictionaryKey:)))
            else {
                print("Failed to swizzle Bundle.infoDictionary.")
                return
        }
        
        method_exchangeImplementations(originalMethod, swizzledMethod)
        
        handler()
        
        method_exchangeImplementations(swizzledMethod, originalMethod)
    }
}
