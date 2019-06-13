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
