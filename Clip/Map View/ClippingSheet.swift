//
//  ClippingSheet.swift
//  Clip
//
//  Created by Riley Testut on 3/20/24.
//  Copyright © 2024 Riley Testut. All rights reserved.
//

import SwiftUI

import ClipKit

@available(iOS 16.4, *)
struct ClippingSheet: View
{
    var pasteboardItem: PasteboardItem
    
    @Environment(\.dismiss)
    private var dismiss
    
    var body: some View {
        NavigationStack {
            ClippingCell(pasteboardItem: pasteboardItem)
                .padding()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Copy", action: copy)
                    }
                    
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: cancel)
                    }
                }
        }
        .presentationBackground(Material.regular)
        .presentationDetents([.fraction(0.33)])
        .tint(.init(uiColor: .clipPink))
    }
}

@available(iOS 16.4, *)
private extension ClippingSheet
{
    func copy()
    {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(center, .ignoreNextPasteboardChange, nil, nil, true)
        
        UIPasteboard.general.copy(self.pasteboardItem)
        
        self.dismiss()
    }
    
    func cancel()
    {
        self.dismiss()
    }
}
