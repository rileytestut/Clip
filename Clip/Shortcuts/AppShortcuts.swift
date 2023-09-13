//
//  AppShortcuts.swift
//  Clip
//
//  Created by Riley Testut on 9/11/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import AppIntents

@available(iOS 16, *)
public struct ShortcutsProvider: AppShortcutsProvider
{
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: PasteIntent(),
                    phrases: [
                        "Paste \(.applicationName)ping",
                    ],
                    shortTitle: "Paste Clipping",
                    systemImageName: "doc.on.doc")
    }
    
    public static var shortcutTileColor: ShortcutTileColor {
        return .pink
    }
}
