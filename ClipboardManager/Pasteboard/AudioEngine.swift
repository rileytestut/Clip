//
//  AudioEngine.swift
//  ClipboardManager
//
//  Created by Riley Testut on 6/12/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import AVFoundation
import CoreAudioKit
import ClipKit

extension AudioEngine
{
    enum Error: LocalizedError
    {
        case extensionNotFound
        
        var errorDescription: String? {
            switch self
            {
            case .extensionNotFound: return NSLocalizedString("Extension could not be found.", comment: "")
            }
        }
    }
}

class AudioEngine
{
    private(set) var isPlaying = false
    
    private let audioEngine: AVAudioEngine
    private let player: AVAudioPlayerNode
    private let audioFile: AVAudioFile
    
    private let queue = DispatchQueue(label: "com.rileytestut.ClipboardManager.AudioEngine")
    
    private var audioUnitExtension: AVAudioUnit?
        
    init()
    {
        self.audioEngine = AVAudioEngine()
        
        self.player = AVAudioPlayerNode()
        self.audioEngine.attach(self.player)
        
        do
        {
            let audioFileURL = Bundle.main.url(forResource: "Silence", withExtension: "m4a")!
            
            self.audioFile = try AVAudioFile(forReading: audioFileURL)
            self.audioEngine.connect(self.player, to: self.audioEngine.mainMixerNode, format: self.audioFile.processingFormat)
        }
        catch
        {
            fatalError("Error. \(error)")
        }
        
        //TODO: Handle audio unit extension crashing.
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
    
    func launchAudioUnitExtension(for componentDescription: AudioComponentDescription, completionHandler: @escaping (Result<AVAudioUnitComponent, Swift.Error>) -> Void)
    {
        DispatchQueue.global().async {
            let availableExtensions = AVAudioUnitComponentManager.shared().components(matching: componentDescription)
            print(availableExtensions.map { $0.audioComponentDescription })
            
            guard let component = availableExtensions.first else { return completionHandler(.failure(Error.extensionNotFound)) }
            
            self.queue.async {
                let outputFormat = self.audioEngine.outputNode.outputFormat(forBus: 0)
                self.audioEngine.connect(self.audioEngine.mainMixerNode, to: self.audioEngine.outputNode, format: outputFormat)
                
                self.player.pause()
                
                if let audioUnit = self.audioUnitExtension
                {
                    self.audioEngine.disconnectNodeInput(audioUnit)
                    self.audioEngine.disconnectNodeInput(self.audioEngine.mainMixerNode)
                    
                    self.audioEngine.connect(self.player, to: self.audioEngine.mainMixerNode, format: self.audioFile.processingFormat)
                    
                    self.audioEngine.detach(audioUnit)
                    self.audioUnitExtension = nil
                }
                
                AVAudioUnit.instantiate(with: component.audioComponentDescription, options: []) { (audioUnit, error) in
                    self.queue.async {
                        guard let audioUnit = audioUnit else { return }
                        
                        self.audioUnitExtension = audioUnit
                        self.audioEngine.attach(audioUnit)
                        
                        self.audioEngine.disconnectNodeInput(self.audioEngine.mainMixerNode)
                        
                        self.audioEngine.connect(self.player, to: audioUnit, format: self.audioFile.processingFormat)
                        self.audioEngine.connect(audioUnit, to: self.audioEngine.mainMixerNode, format: self.audioFile.processingFormat)
                        
                        if self.isPlaying
                        {
                            self.player.play()
                        }
                        
                        completionHandler(.success(component))
                    }
                }
            }
        }
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
}
