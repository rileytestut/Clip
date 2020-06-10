//
//  ClippingCell.swift
//  ClipKit
//
//  Created by Riley Testut on 5/25/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import SwiftUI
import CoreData
import MobileCoreServices

private extension Formatter
{
    static let clipFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 1
        formatter.allowedUnits = [.second, .minute, .hour, .day]
        return formatter
    }()
}

struct ClippingCell: View
{
    @ObservedObject var pasteboardItem: PasteboardItem
        
    var body: some View {
        let representation = self.pasteboardItem.preferredRepresentation
        let dateString = Formatter.clipFormatter.string(from: self.pasteboardItem.date, to: Date())

        return Group {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(representation?.type.localizedName ?? "Unknown")
                        .font(.headline)
                    
                    Spacer()
                                            
                    Text(dateString ?? "")
                        .font(.caption)
                }
                .foregroundColor(Color(.clipPink))
                
                if representation?.stringValue != nil
                {
                    Text(representation!.stringValue!)
                        .font(.subheadline)
                        .lineLimit(6)
                }
            }
            .padding(.horizontal, nil)
            .padding(.vertical, 8)
        }
        .background(Blur())
        .colorScheme(.light)
        .blurStyle(.extraLight)
        .frame(minWidth: 0, maxWidth: .infinity)
        .cornerRadius(10)
    }
}

struct ClippingCell_Previews: PreviewProvider
{
    static var previews: some View
    {
        Preview.prepare()
        
        let context = DatabaseManager.shared.persistentContainer.viewContext
        let date = Date().addingTimeInterval(-1 * 60 * 60)
        
        let item = PasteboardItem.make(item: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum." as NSString, date: date, context: context)
        
        return ClippingCell(pasteboardItem: item)
            .background(Color(.clipPink))
            .environment(\.managedObjectContext, context)
            .previewLayout(.sizeThatFits)
    }
}
