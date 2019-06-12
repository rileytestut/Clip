//
//  PasteboardMonitor.swift
//  ClipboardManager
//
//  Created by Riley Testut on 6/11/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit
import AVFoundation
import MobileCoreServices
import UserNotifications

import Roxas

struct PasteboardItem
{
    enum Representation: CustomStringConvertible
    {
        case text(String)
        case attributedText(NSAttributedString)
        case image(UIImage)
        case url(URL)
        case other(Any)
        
        var description: String {
            switch self
            {
            case .text(let text): return "Text: \(text)"
            case .attributedText(let attributedText): return "Attributed Text: \(attributedText.string)"
            case .image(let image): return "Image: \(image.size)"
            case .url(let url): return "URL: \(url)"
            case .other(let other): return "Other: \(other)"
            }
        }
    }
    
    var representations: [Representation]
}

class PasteboardMonitor
{
    static let shared = PasteboardMonitor()
    
    private(set) var isStarted = false
    
    private var player: AVAudioPlayer?
    private var pollingTimer: Timer?
    private var previousChangeCount: Int?
    
    private init()
    {
    }
}

extension PasteboardMonitor
{
    func start()
    {
        guard !self.isStarted else { return }
        
        self.isStarted = true
        
        // Allows us to test in simulator for now before we have full background support.
        var backgroundTaskID: UIBackgroundTaskIdentifier?
        backgroundTaskID = UIApplication.shared.beginBackgroundTask {
            UIApplication.shared.endBackgroundTask(backgroundTaskID!)
        }
                
        do
        {
            // Start silent audio
            let audioURL = Bundle.main.url(forResource: "Blank", withExtension: "wav")!

            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)

            let player = try AVAudioPlayer(contentsOf: audioURL)
            player.numberOfLoops = -1
            player.volume = 0.01
            player.prepareToPlay()
            player.play()
            self.player = player

            print("Playing audio...")
        }
        catch
        {
            print("Failed to configure audio session.", error)
        }
        
        self.previousChangeCount = UIPasteboard.general.changeCount
        self.pollingTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(PasteboardMonitor.poll), userInfo: nil, repeats: true)
    }
}

private extension PasteboardMonitor
{
    @objc func poll()
    {
        print("Polling... ", UIPasteboard.general.changeCount, UIApplication.shared.backgroundTimeRemaining)
        
        guard case let changeCount = UIPasteboard.general.changeCount, changeCount != self.previousChangeCount else { return }
        
        self.previousChangeCount = changeCount
        self.pasteboardDidUpdate()
    }
    
    func pasteboardDidUpdate()
    {
        guard !UIPasteboard.general.hasColors else { return } // Accessing UIPasteboard.items causes crash as of iOS 12.3 if it contains a UIColor.
        
        for item in UIPasteboard.general.items
        {
            var representations = [PasteboardItem.Representation]()
            
            for (uti, value) in item
            {
                switch (uti, value)
                {
                case (let uti as CFString, let string as String) where UTTypeConformsTo(uti, kUTTypeRTF):
                    guard let data = string.data(using: .utf8) else { continue }
                    guard let attributedString = try? NSAttributedString(data: data, options: [.documentType : NSAttributedString.DocumentType.rtf], documentAttributes: nil) else { continue }
                    
                    representations.append(.attributedText(attributedString))
                    
                case (let uti as CFString, let string as String) where UTTypeConformsTo(uti, kUTTypeHTML):
                    guard let data = string.data(using: .utf8) else { continue }
                    guard let attributedString = try? NSAttributedString(data: data, options: [.documentType : NSAttributedString.DocumentType.html], documentAttributes: nil) else { continue }
                    
                    representations.append(.attributedText(attributedString))
                    
                case (let uti as CFString, let string as String) where UTTypeConformsTo(uti, kUTTypeText): representations.append(.text(string))
                case (let uti as CFString, let url as URL) where UTTypeConformsTo(uti, kUTTypeURL): representations.append(.url(url))
                case (let uti as CFString, let image as UIImage) where UTTypeConformsTo(uti, kUTTypeImage): representations.append(.image(image))
                
                default: representations.append(.other(value))
                }
            }
            
            guard let representation = representations.first(where: { (representation) -> Bool in
                switch representation
                {
                case .text, .url: return true
                default: return false
                }
            }) else { return }
            
            let content = UNMutableNotificationContent()
            content.title = "Clipboard Saved"
            content.body = String(describing: representation)
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
            
            let request = UNNotificationRequest(identifier: "ClipboardChanged", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request) { (error) in
                if let error = error {
                    print(error)
                }
            }
        }
    }
}
