//
//  SwitchKeyboardButton.swift
//  ClipKit
//
//  Created by Riley Testut on 6/9/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import SwiftUI

struct SwitchKeyboardButton: UIViewRepresentable
{
    var inputViewController: UIInputViewController?
    
    var tintColor: UIColor? = nil
    var configuration: UIImage.SymbolConfiguration? = nil
    
    func makeUIView(context: Context) -> UIButton
    {
        let button = UIButton(type: .system)
        button.tintColor = self.tintColor
        button.addTarget(self.inputViewController,
                         action: #selector(UIInputViewController.handleInputModeList(from:with:)),
                         for: .allTouchEvents)
        
        button.setImage(UIImage(systemName: "globe", withConfiguration: self.configuration), for: .normal)
        button.sizeToFit()
        
        return button
    }
    
    func updateUIView(_ button: UIButton, context: Context)
    {
    }
}

struct SwitchKeyboardButton_Previews: PreviewProvider
{
    static var previews: some View {
        Group {
            SwitchKeyboardButton(inputViewController: nil)
                .fixedSize()
            
            SwitchKeyboardButton(inputViewController: nil,
                                 tintColor: .clipPink,
                                 configuration: .init(textStyle: .title1))
                .fixedSize()
        }
        .previewLayout(.sizeThatFits)
    }
}
