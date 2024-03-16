//
//  AudioEngine.swift
//  Clip
//
//  Created by Riley Testut on 6/12/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import AVFoundation
import CoreAudioKit
import UserNotifications

import ClipKit

extension UserDefaults
{
    @NSManaged
    fileprivate var preferredAudioFileURL: URL?
}

class AudioEngine: NSObject
{
    @objc dynamic
    private(set) var isPlaying = false
    
    public private(set) var preferredAudioFileURL: URL? {
        get {
            UserDefaults.shared.preferredAudioFileURL
        }
        set {
            UserDefaults.shared.preferredAudioFileURL = newValue
        }
    }
    
    private let audioEngine: AVAudioEngine
    private let player: AVAudioPlayerNode
    private var audioFile: AVAudioFile!
    
    private let queue = DispatchQueue(label: "com.rileytestut.Clip.AudioEngine")
    
    override init()
    {
        self.audioEngine = AVAudioEngine()
        
        self.player = AVAudioPlayerNode()
        self.audioEngine.attach(self.player)
        
        let outputFormat = self.audioEngine.outputNode.outputFormat(forBus: 0)
        self.audioEngine.connect(self.audioEngine.mainMixerNode, to: self.audioEngine.outputNode, format: outputFormat)
        
        super.init()
        
        self.prepareAudioFile()
        
        NotificationCenter.default.addObserver(self, selector: #selector(AudioEngine.audioSessionWasInterrupted(_:)), name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance())
        NotificationCenter.default.addObserver(self, selector: #selector(AudioEngine.applicationWillEnterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    func prepareAudioFile()
    {
        do
        {
            let fileURL: URL
            
            if let preferredAudioFileURL = UserDefaults.shared.preferredAudioFileURL
            {
                fileURL = preferredAudioFileURL
            }
            else
            {
                fileURL = Bundle.main.url(forResource: "Silence", withExtension: "m4a")!
            }
                                
            self.audioFile = try AVAudioFile(forReading: fileURL)
            self.audioEngine.connect(self.player, to: self.audioEngine.mainMixerNode, format: self.audioFile.processingFormat)
        }
        catch
        {
            print("Failed to prepare audio file.", error.localizedDescription)
        }
    }
}

extension AudioEngine
{
    func start() throws
    {
        try self.queue.sync {
            guard !self.isPlaying else { return }
            
            try AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            
            // Schedule audio file buffers.
            scheduleAudioFile()
            scheduleAudioFile()
            
            let outputFormat = self.audioEngine.outputNode.outputFormat(forBus: 0)
            self.audioEngine.connect(self.audioEngine.mainMixerNode, to: self.audioEngine.outputNode, format: outputFormat)
            
            try self.audioEngine.start()
            
            self.player.play()
            
            self.isPlaying = true
        }
    }
    
    func stop()
    {
        self.queue.sync {
            guard self.isPlaying else { return }
            
            self.player.stop()
            self.audioEngine.stop()
            
            self.isPlaying = false
        }
    }
    
    func reset() throws
    {
        guard self.isPlaying else { return }
        
        self.stop()
        try self.start()
    }
    
    func changeAudioFile(to fileURL: URL)
    {
        guard fileURL.startAccessingSecurityScopedResource() else { return }
        defer {
            fileURL.stopAccessingSecurityScopedResource()
        }
        
        do
        {
            let audioDirectory = URL.documentsDirectory.appendingPathComponent("Audio")
            try FileManager.default.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
            
            let destinationURL = audioDirectory.appending(path: fileURL.lastPathComponent)
            try FileManager.default.copyItem(at: fileURL, to: destinationURL, shouldReplace: true)
            
            self.stop()
            self.preferredAudioFileURL = destinationURL
            
            self.prepareAudioFile()
        }
        catch
        {
            print("Failed to change audio file.", error.localizedDescription)
        }
    }
    
    func resetAudioFile()
    {
        self.stop()
        
        if let preferredAudioFileURL = self.preferredAudioFileURL
        {
            do
            {
                try FileManager.default.removeItem(at: preferredAudioFileURL)
            }
            catch
            {
                print("Failed to remove preferred audio file.", error.localizedDescription)
            }
        }
        
        self.preferredAudioFileURL = nil
        
        self.prepareAudioFile()
    }
}

private extension AudioEngine
{
    func scheduleAudioFile()
    {
        self.player.scheduleFile(self.audioFile, at: nil) {
            self.queue.async {
                guard self.isPlaying else { return }
                self.scheduleAudioFile()
            }
        }
    }
    
    @objc func audioSessionWasInterrupted(_ notification: Notification)
    {
        guard
            let userInfo = notification.userInfo,
            let rawType = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: rawType)
        else { return }
        
        switch type
        {
        case .began:
            self.stop()
                
        case .ended:
            do
            {
                try self.reset()
            }
            catch
            {
                print("Failed to reset AudioEngine after AVAudioSession interruption.", error)
            }
            
        @unknown default: break
        }
    }
    
    @objc private func applicationWillEnterForeground(_ notification: Notification)
    {
        guard !self.isPlaying else { return }
        
        do
        {
            try self.reset()
        }
        catch
        {
            print("Failed to reset AudioEngine upon returning to foreground.", error)
        }
    }
}
