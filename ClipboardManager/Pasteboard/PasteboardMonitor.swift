//
//  PasteboardMonitor.swift
//  ClipboardManager
//
//  Created by Riley Testut on 6/11/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit
import AVFoundation

import Roxas

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
        
        DatabaseManager.shared.persistentContainer.performBackgroundTask { (context) in
            let pasteboardItems = UIPasteboard.general.items.compactMap { (representations) -> PasteboardItem? in
                let representations = representations.compactMap { PasteboardItemRepresentation(uti: $0, value: $1, context: context) }
                
                let pasteboardItem = PasteboardItem(representations: representations, context: context)
                return pasteboardItem
            }
            
            print(pasteboardItems)
            
            do { try context.save() } catch { print("Error saving pasteboard data.", error) }
        }
    }
}
