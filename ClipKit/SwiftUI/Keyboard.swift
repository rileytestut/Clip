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

@objc
private protocol RSTApplication: AnyObject
{
    @objc(openURL:options:completionHandler:)
    func open(_ url: URL, options: [UIApplication.OpenExternalURLOptionsKey : Any], completionHandler completion: (@MainActor @Sendable (Bool) -> Void)?)
}

public struct Keyboard: View
{
    private let inputViewController: UIInputViewController?
    private let needsInputModeSwitchKey: Bool
    private let hasFullAccess: Bool
    
    @FetchRequest(fetchRequest: PasteboardItem.historyFetchRequest())
    private var pasteboardItems: FetchedResults<PasteboardItem>
    
    public init(inputViewController: UIInputViewController?,
                needsInputModeSwitchKey: Bool? = nil,
                hasFullAccess: Bool? = nil)
    {
        self.inputViewController = inputViewController
        self.needsInputModeSwitchKey = needsInputModeSwitchKey ?? inputViewController?.needsInputModeSwitchKey ?? false
        self.hasFullAccess = hasFullAccess ?? inputViewController?.hasFullAccess ?? true
    }
        
    public var body: some View {
        ZStack(alignment: .bottomLeading) {
            
            if !self.hasFullAccess
            {
                VStack(spacing: 32) {
                    VStack(spacing: 16) {
                        Text("Full Access Required")
                            .font(.title)
                        Text("Allow Full Access for this keyboard in Settings to access saved clippings.")
                            .font(.body)
                    }
                    
                    Button(action: self.openSettings) {
                        Text("Open Settings")
                            .font(Font(UIFont.preferredFont(forTextStyle: .title3)))
                            .foregroundColor(Color(.clipPink))
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .padding()
            }
            else if self.pasteboardItems.isEmpty
            {
                VStack(spacing: 16) {
                    Text("No Clippings")
                        .font(.title)
                    Text("Items that you've copied to the clipboard will appear here.")
                        .font(.body)
                }
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .padding()
            }
            else
            {
                List(self.pasteboardItems, id: \.objectID) { (pasteboardItem) in
                    Button(action: { self.paste(pasteboardItem) }) {
                        ClippingCell(pasteboardItem: pasteboardItem)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(makeInsets())
                }
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
    
    private func makeInsets() -> EdgeInsets
    {
        var insets = EdgeInsets()
        insets.top = 8
        insets.bottom = 8
        return insets
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
    
    func openSettings()
    {
        // NSExtensionContext.openURL() can only be called from Today extensions.
        // As a workaround, we can just call UIApplication.openURL(),
        // but we can't call it directly because it's marked as unavailable for extensions.
        guard
            let application = (UIApplication.self as AnyObject).value(forKey: "sharedApplication") as? UIApplication
        else { return }
        
        // UIApplication.openSettingsURLString doesn't work from keyboard extension,
        // so instead we open Clip which will then open Settings.
        let openURL = URL(string: "clip://settings")!
        
        let tempApp = unsafeBitCast(application, to: RSTApplication.self)
        tempApp.open(openURL, options: [:], completionHandler: nil)
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
                
        return Group {
            Keyboard(inputViewController: nil, needsInputModeSwitchKey: true)
            Keyboard(inputViewController: nil, needsInputModeSwitchKey: true, hasFullAccess: false)
        }
        .background(Color(.lightGray))
        .environment(\.managedObjectContext, context)
        .previewLayout(.fixed(width: 375, height: 500))
    }
}
