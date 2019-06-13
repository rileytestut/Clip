//
//  ListenerUnit.swift
//  ClipKit
//
//  Created by Riley Testut on 6/12/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import AudioToolbox
import AVFoundation

public class ListenerUnit: AUAudioUnit
{
    private let inputBus: AUAudioUnitBus
    private let outputBus: AUAudioUnitBus
    
    private var _inputBusses: AUAudioUnitBusArray!
    private var _outputBusses: AUAudioUnitBusArray!
    
    public override var canProcessInPlace: Bool {
        return true
    }
    
    public override var inputBusses: AUAudioUnitBusArray {
        return _inputBusses
    }
    
    public override var outputBusses: AUAudioUnitBusArray {
        return _outputBusses
    }
    
    public override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions = []) throws
    {
        guard let defaultFormat = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 2) else { throw AVError(.formatUnsupported) }
        self.inputBus = try AUAudioUnitBus(format: defaultFormat)
        self.outputBus = try AUAudioUnitBus(format: defaultFormat)
        
        try super.init(componentDescription: componentDescription, options: options)
        
        _inputBusses = AUAudioUnitBusArray(audioUnit: self, busType: .input, busses: [self.inputBus])
        _outputBusses = AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [self.outputBus])
        
        self.maximumFramesToRender = 5012
    }
    
    public override var internalRenderBlock: AUInternalRenderBlock {
        let renderBlock: @convention(block)
            (UnsafeMutablePointer<AudioUnitRenderActionFlags>, UnsafePointer<AudioTimeStamp>, AUAudioFrameCount, Int, UnsafeMutablePointer<AudioBufferList>, UnsafePointer<AURenderEvent>?, AURenderPullInputBlock?) -> AUAudioUnitStatus = { (actionFlags, timestamp, frameCount, outputBusNumber, outputData, realtimeEventListHead, pullInputBlock) in
            return noErr
        }
        return renderBlock
    }
}
