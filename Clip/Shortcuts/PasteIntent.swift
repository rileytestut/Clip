//
//  CopyClippingIntent.swift
//  Clip
//
//  Created by Riley Testut on 9/11/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import AppIntents
import UIKit
import SwiftUI

@available(iOS 16, *)
class IntentError: NSError, CustomLocalizedStringResourceConvertible
{
    var localizedStringResource: LocalizedStringResource {
        return "\(self.localizedDescription)"
    }
    
    init(_ error: some Error)
    {
        let nsError = error as NSError
        super.init(domain: nsError.domain, code: nsError.code, userInfo: nsError.userInfo)
    }
    
    required init?(coder: NSCoder)
    {
        super.init(coder: coder)
    }
}

@available(iOS 16, *)
struct PasteIntent: AppIntent
{
    static var title: LocalizedStringResource { "Paste Clipping" }
    static var isDiscoverable: Bool { true }
    
    @available(iOS 17, *)
    static var description: IntentDescription? {
        IntentDescription("Copy a recent clipping to the Clipboard.", resultValueName: "Clipping")
    }
    
//    static var parameterSummary: SummaryContent {
//        
//    }
    
    @Parameter(title: "Clipping", description: "The clipping to copy to the Clipboard.")
    var clipping: ClippingEntity
    
    func perform() async throws -> some ReturnsValue<IntentFile>
    {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(center, .ignoreNextPasteboardChange, nil, nil, true)
        
        UIPasteboard.general.copy(self.clipping.pasteboardItem)
        
        return .result(value: clipping.data)
    }
}

//struct ClippingsOptionProvider: DynamicOptionsProvider
//{
//    func results() async throws -> some ResultsCollection 
//    {
//        <#code#>
//    }
//}
