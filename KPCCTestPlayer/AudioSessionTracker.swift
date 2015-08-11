//
//  SessionTracker.swift
//  KPCCTestPlayer
//
//  Created by Eric Richardson on 5/3/15.
//  Copyright (c) 2015 Eric Richardson. All rights reserved.
//

import Foundation
import CoreData

public class AudioSessionTracker {
    public static let sharedInstance = AudioSessionTracker()
    
    public struct Session {
        public var started_at:NSDate
        public var ended_at:NSDate? = nil
        public var session_ids:[String] = []
        
        public var durations:[AudioPlayer.Statuses:Double] = [:]
        public var stalls:Int = 0
        
        init() {
            started_at = NSDate()
        }
    }
    
    private struct CurrentState {
        var state:AudioPlayer.Statuses
        var started:NSDate
    }
    
    private var _session:Session?
    private var _curState:CurrentState?
    private var _lastActiveAt:NSDate?
    
    init() {        
        // listen for player state changes
        AudioPlayer.sharedInstance.oStatus.addObserver() { status in
            // is this the start of a new session?
            if self._session == nil {
                NSLog("Session: New session starting.")
                self._session = Session()
            }
            
            // do we have a session id?
            let sid = AudioPlayer.sharedInstance._sessionId
            if sid != nil && (self._session!.session_ids.count == 0 || sid != self._session!.session_ids.last)  {
                NSLog("Session: Adding AVPlayer session_id -- \(sid!)")
                self._session!.session_ids.append(sid!)
            }
            
            // how long were we in our previous state?
            if self._curState != nil {
                let duration = abs(self._curState!.started.timeIntervalSinceNow)
                
                if self._session!.durations[self._curState!.state] == nil {
                    self._session!.durations[self._curState!.state] = 0
                }
                
                self._session!.durations[self._curState!.state]! += duration
                NSLog("Session: Logged \(duration) seconds in the \(self._curState!.state.toString()) state.")
            }
            
            // start watching for our new time
            self._curState = CurrentState(state:status,started:NSDate())
        }
    }
}