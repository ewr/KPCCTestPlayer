//
//  EventLog.swift
//  KPCCTestPlayer
//
//  Created by Eric Richardson on 5/2/15.
//  Copyright (c) 2015 Eric Richardson. All rights reserved.
//

import Foundation

class EventLog {
    static let sharedInstance = EventLog()
    
    let _player = AudioPlayer.sharedInstance
    
    var maxItems = 100
    
    private var _events:[AudioPlayer.Event] = []
    
    init() {
        self._player.oEventLog.addObserver() { event in
            self._events.append(event)
            
            if self._events.count > 100 {
                self._events.removeAtIndex(0)
            }
        }
    }
    
    func events() -> [AudioPlayer.Event] {
        return self._events
    }
}