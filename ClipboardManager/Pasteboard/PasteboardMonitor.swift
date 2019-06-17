//
//  PasteboardMonitor.swift
//  ClipboardManager
//
//  Created by Riley Testut on 6/11/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit
import AVFoundation

import ClipKit
import Roxas

let PasteboardMonitorDidChangePasteboard: @convention(c) (CFNotificationCenter?, UnsafeMutableRawPointer?, CFNotificationName?, UnsafeRawPointer?, CFDictionary?) -> Void =
{ (center, observer, name, object, userInfo) in
    PasteboardMonitor.shared.didChangePasteboard()
}

class PasteboardMonitor
{
    static let shared = PasteboardMonitor()
    
    private(set) var isStarted = false
    
    private let audioEngine = AudioEngine()
    private let feedbackGenerator = UINotificationFeedbackGenerator()
    
    private init()
    {
    }
}

extension PasteboardMonitor
{
    func start(completionHandler: @escaping (Result<Void, Error>) -> Void)
    {
        guard !self.isStarted else { return }
        
        DispatchQueue.global().async {
            do
            {
                try self.audioEngine.start()
                
                self.audioEngine.launchAudioUnitExtension(for: .listenerUnit) { (result) in
                    switch result
                    {
                    case .failure(let error): completionHandler(.failure(error))
                    case .success:
                        self.registerForExtensionNotifications()
                        self.isStarted = true
                    }
                }
            }
            catch
            {
                completionHandler(.failure(error))
            }
        }
    }
    
    func copy(_ pasteboardItem: PasteboardItem)
    {
        var representations = pasteboardItem.representations.reduce(into: [:]) { $0[$1.uti] = $1.pasteboardValue }
        representations[UTI.clipping] = [:]
        
        UIPasteboard.general.setItems([representations], options: [:])
    }
}

private extension PasteboardMonitor
{
    func registerForExtensionNotifications()
    {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterAddObserver(center, nil, PasteboardMonitorDidChangePasteboard, CFNotificationName.didChangePasteboard.rawValue, nil, .deliverImmediately)
    }
    
    func didChangePasteboard()
    {
        DatabaseManager.shared.refresh()
        
        self.feedbackGenerator.notificationOccurred(.success)
    }
}
