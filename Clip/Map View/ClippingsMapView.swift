//
//  HistoryMapView.swift
//  Clip
//
//  Created by Riley Testut on 3/20/24.
//  Copyright © 2024 Riley Testut. All rights reserved.
//

import MapKit
import UIKit
import SwiftUI

import ClipKit

@available(iOS 17, *)
class ClippingsMapViewController: UIHostingController<AnyView>
{
    @MainActor 
    required dynamic init?(coder aDecoder: NSCoder) {
        let view = AnyView(erasing: ClippingsMapView().environment(\.managedObjectContext, DatabaseManager.shared.persistentContainer.viewContext))
        super.init(coder: aDecoder, rootView: view)
        
        self.tabBarItem.image = UIImage(systemName: "map")
    }
}

@MainActor @available(iOS 17, *)
struct ClippingsMapView: View
{
    @FetchRequest(fetchRequest: PasteboardItem.historyFetchRequest())
    private var pasteboardItems: FetchedResults<PasteboardItem>
    
    @State
    private var selectedItem: PasteboardItem?
    
    var body: some View {
        Map(selection: $selectedItem) {
            // Must use \.self as keypath for selection to work
            ForEach(pasteboardItems, id: \.self) { pasteboardItem in
                if let location = pasteboardItem.location
                {
                    Marker(pasteboardItem.date.formatted(), systemImage: "paperclip", coordinate: location.coordinate)
                }
            }
        }
        .sheet(item: $selectedItem) { pasteboardItem in
            ClippingSheet(pasteboardItem: pasteboardItem)
        }
    }
}
