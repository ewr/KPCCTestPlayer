//
//  AudioPlayerTests.swift
//  KPCCTestPlayer
//
//  Created by Eric Richardson on 2/7/15.
//  Copyright (c) 2015 Eric Richardson. All rights reserved.
//

import Quick
import Nimble

import KPCCTestPlayer
import AVFoundation

class AudioPlayerSpec: QuickSpec {
    override func spec() {
        describe("AudioPlayer") {
            it("returns a shared global instance of itself") {
                let p1 = AudioPlayer.sharedInstance
                let p2 = AudioPlayer.sharedInstance
                
                expect(p1) === p2
            }
            
            it("can play the stream") {
                let p = AudioPlayer.sharedInstance
                
                
            }
        }
    }
}