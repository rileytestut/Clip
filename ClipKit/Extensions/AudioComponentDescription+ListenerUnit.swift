//
//  AudioComponentDescription+ListenerUnit.swift
//  ClipKit
//
//  Created by Riley Testut on 6/13/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import AudioToolbox

public extension AudioComponentDescription
{
    static let listenerUnit = AudioComponentDescription(componentType: kAudioUnitType_Effect,
                                                        componentSubType: "clip".osType,
                                                        componentManufacturer: "RILE".osType,
                                                        componentFlags: 0,
                                                        componentFlagsMask: 0)
}

// Conforming types we don't own to protocols we also don't own, always a Good Idea™️.
extension AudioComponentDescription: Equatable
{
    public static func == (lhs: AudioComponentDescription, rhs: AudioComponentDescription) -> Bool
    {
        return
            lhs.componentType == rhs.componentType &&
            lhs.componentSubType == rhs.componentSubType &&
            lhs.componentManufacturer == rhs.componentManufacturer &&
            lhs.componentFlags == rhs.componentFlags &&
            lhs.componentFlagsMask == rhs.componentFlagsMask
    }
}
