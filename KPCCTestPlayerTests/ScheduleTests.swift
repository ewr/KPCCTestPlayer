//
//  ScheduleTests.swift
//  KPCCTestPlayer
//
//  Created by Eric Richardson on 2/15/15.
//  Copyright (c) 2015 Eric Richardson. All rights reserved.
//

import Quick
import Nimble

import KPCCTestPlayer
import AVFoundation

class ScheduleSpec: QuickSpec {
    override func spec() {
        describe("Schedule") {
            it("returns a shared global instance of itself") {
                let s1 = Schedule.sharedInstance
                let s2 = Schedule.sharedInstance
                
                expect(s1) === s2
            }
            
            //----------

            it("can return a ShowInstance for now") {
                let now = NSDate()
                
                waitUntil { done in
                    Schedule.sharedInstance.at(now) { show in
                        expect(show).toNot(beNil())
                        
                        expect(show!.starts_at.timeIntervalSinceReferenceDate) <= now.timeIntervalSinceReferenceDate
                        expect(show!.ends_at.timeIntervalSinceReferenceDate) > now.timeIntervalSinceReferenceDate

                        done()
                    }
                }
            }
            
            //----------
            
            it("can return multiple ShowInstances for a period of time") {
                let now         = NSDate()
                let four_hours  = now.dateByAddingTimeInterval(4*60*60)
                
                waitUntil { done in
                    Schedule.sharedInstance.from(now, end: four_hours) { shows in
                        expect(shows).toNot(beNil())
                        expect(shows?.isEmpty).to(beFalse())
                        
                        expect(shows!.first!.starts_at.timeIntervalSinceReferenceDate) <= now.timeIntervalSinceReferenceDate
                        expect(shows!.last!.ends_at.timeIntervalSinceReferenceDate) > four_hours.timeIntervalSinceReferenceDate
                        
                        done()
                    }
                }
                
            }
        }
    }
}