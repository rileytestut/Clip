//
//  Keyboard.swift
//  ClipKit
//
//  Created by Riley Testut on 5/25/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import SwiftUI
import CoreData
import UIKit

import Roxas

public struct Keyboard: View
{
    private let inputViewController: UIInputViewController?
    private let needsInputModeSwitchKey: Bool
    
    @FetchRequest(fetchRequest: PasteboardItem.historyFetchRequest())
    private var pasteboardItems: FetchedResults<PasteboardItem>
    
    public init(inputViewController: UIInputViewController?,
                needsInputModeSwitchKey: Bool? = nil)
    {
        self.inputViewController = inputViewController
        self.needsInputModeSwitchKey = needsInputModeSwitchKey ?? inputViewController?.needsInputModeSwitchKey ?? false
    }
    
    public var body: some View {
        ZStack(alignment: .bottomLeading) {
            List(self.pasteboardItems, id: \.objectID) { (pasteboardItem) in
                Button(action: { self.paste(pasteboardItem) }) {
                    ClippingCell(pasteboardItem: pasteboardItem)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            if self.needsInputModeSwitchKey
            {
                SwitchKeyboardButton(inputViewController: self.inputViewController,
                                     tintColor: .clipPink,
                                     configuration: .init(textStyle: .title2))
                    .fixedSize()
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
                    .background(Blur())
                    .blurStyle(.extraLight)
                    .clipShape(Circle())
                    .offset(x: 8, y: -8)
            }
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            UITableView.appearance().backgroundColor = .clear
            UITableView.appearance().separatorStyle = .none
            UITableView.appearance().contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
            
            UITableViewCell.appearance().backgroundColor = .clear
        }
    }
}

private extension Keyboard
{
    func paste(_ pasteboardItem: PasteboardItem)
    {
        guard let text = pasteboardItem.preferredRepresentation?.stringValue else { return }
        self.inputViewController?.textDocumentProxy.insertText(text)
        
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(center, .ignoreNextPasteboardChange, nil, nil, true)
        
        UIPasteboard.general.copy(pasteboardItem)
        
        self.inputViewController?.inputView?.playInputClick()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.inputViewController?.advanceToNextInputMode()
        }
    }
}

struct Keyboard_Previews: PreviewProvider
{
    static var previews: some View
    {
        Preview.prepare()
        
        let context = DatabaseManager.shared.persistentContainer.viewContext
        let date = Date().addingTimeInterval(-1 * 60 * 60)
        
        _ = PasteboardItem.make(item: "Hello SwiftUI!" as NSString, date: date, context: context)
        _ = PasteboardItem.make(item: NSURL(string: "https://rileytestut.com")!, date: date, context: context)
        _ = PasteboardItem.make(item: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum." as NSString, date: date, context: context)
                
        return Keyboard(inputViewController: nil)
            .background(Color(.lightGray))
            .environment(\.managedObjectContext, context)
            .previewLayout(.fixed(width: 375, height: 500))
    }
}
