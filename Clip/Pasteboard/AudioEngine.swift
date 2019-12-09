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

class AudioEngine
{
    private(set) var isPlaying = false
    
    private let audioEngine: AVAudioEngine
    private let player: AVAudioPlayerNode
    private let audioFile: AVAudioFile
    
    private let queue = DispatchQueue(label: "com.rileytestut.Clip.AudioEngine")
    
    init()
    {
        self.audioEngine = AVAudioEngine()
        self.audioEngine.mainMixerNode.outputVolume = 0.0
        
        self.player = AVAudioPlayerNode()
        self.audioEngine.attach(self.player)
        
        do
        {
            let audioFileURL = Bundle.main.url(forResource: "Silence", withExtension: "m4a")!
            
            self.audioFile = try AVAudioFile(forReading: audioFileURL)
            self.audioEngine.connect(self.player, to: self.audioEngine.mainMixerNode, format: self.audioFile.processingFormat)
            
            let outputFormat = self.audioEngine.outputNode.outputFormat(forBus: 0)
            self.audioEngine.connect(self.audioEngine.mainMixerNode, to: self.audioEngine.outputNode, format: outputFormat)
        }
        catch
        {
            fatalError("Error. \(error)")
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(AudioEngine.audioSessionWasInterrupted(_:)), name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance())
        NotificationCenter.default.addObserver(self, selector: #selector(AudioEngine.applicationWillEnterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)
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
        self.stop()
        try self.start()
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
