//
//  Blur.swift
//  ClipKit
//
//  Created by Riley Testut on 5/25/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import SwiftUI
import UIKit

fileprivate struct BlurStyleKey: EnvironmentKey
{
    static let defaultValue: UIBlurEffect.Style = .regular
}

public extension EnvironmentValues
{
    var blurStyle: UIBlurEffect.Style {
        get { self[BlurStyleKey.self] }
        set { self[BlurStyleKey.self] = newValue }
    }
}

public extension View
{
    func blurStyle(_ blurStyle: UIBlurEffect.Style) -> some View {
        environment(\.blurStyle, blurStyle)
    }
}

public struct Blur: View, UIViewRepresentable
{
    @Environment(\.blurStyle) var blurStyle: UIBlurEffect.Style

    public func makeUIView(context: Context) -> UIVisualEffectView
    {
        let visualEffectView = UIVisualEffectView(effect: nil)
        updateUIView(visualEffectView, context: context)

        return visualEffectView
    }

    public func updateUIView(_ uiView: UIVisualEffectView, context: Context)
    {
        let blurEffect = UIBlurEffect(style: self.blurStyle)
        uiView.effect = blurEffect
    }
}

struct Blur_Previews: PreviewProvider
{
    static var previews: some View {
        ZStack {
            Color.blue
            Blur()
            Text("Hello World!")
        }
        .colorScheme(.dark)
        .previewLayout(.fixed(width: 300, height: 300))
    }
}
