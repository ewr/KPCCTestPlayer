//
//  observer.swift
//  KPCCTestPlayer
//
//  Created by Eric Richardson on 1/25/15.
//  Copyright (c) 2015 Eric Richardson. All rights reserved.
//

import Foundation
import AVFoundation

class AVObserver: NSObject {
    typealias CallbackClosure   = ( (Statuses,String,AnyObject?) -> Void )
    typealias OnceClosure       = (String,AnyObject?) -> Void
    
    let _callback:CallbackClosure
    let _player:AVPlayer
    
    var _once = [Statuses:[OnceClosure]]()
    
    enum Statuses {
        case PlayerFailed, PlayerReady, ItemFailed, ItemReady, Playing, Paused, Stalled, TimeJump, AccessLog, ErrorLog
    }
    
    let _itemNotifications = [
        AVPlayerItemPlaybackStalledNotification,
        AVPlayerItemTimeJumpedNotification,
        AVPlayerItemNewAccessLogEntryNotification,
        AVPlayerItemNewErrorLogEntryNotification
    ]
    
    init(player:AVPlayer,callback:CallbackClosure) {
        self._player = player
        self._callback = callback
        
        super.init()
        
        player.addObserver(self, forKeyPath:"status", options: nil, context: nil)
        player.addObserver(self, forKeyPath:"rate", options: nil, context: nil)
        player.currentItem.addObserver(self, forKeyPath:"status", options: nil, context: nil)
        
        // also subscribe to notifications from currentItem
        for n in self._itemNotifications {
            NSNotificationCenter.defaultCenter().addObserver(self, selector:"item_notification:", name: n, object: player.currentItem)
        }
    }
    
    //----------
    
    func stop() {
        
    }
    
    //----------
    
    func once(status:Statuses,callback:OnceClosure) -> Void {
        if (self._once[status] == nil) {
            self._once[status] = []
        }
        
        self._once[status]?.append(callback)
    }
    
    //----------
    
    private func _notify(status:Statuses,msg:String,obj:AnyObject? = nil) -> Void {
        // always notify our callback
        self._callback(status,msg,obj)
        
        if let callbacks = self._once[status] {
            // alert the array of callbacks
            for c in callbacks {
                c(msg,obj)
            }
            
            self._once.removeValueForKey(status)
        }
    }
    
    //----------
    
    func item_notification(notification:NSNotification) -> Void {
        switch notification.name {
        case AVPlayerItemPlaybackStalledNotification:
            self._notify(Statuses.Stalled,msg: "Playback Stalled")
        case AVPlayerItemTimeJumpedNotification:
            self._notify(Statuses.TimeJump,msg: "Time jumped.")
        case AVPlayerItemNewErrorLogEntryNotification:
            // try and pull the log...
            let log:AVPlayerItemErrorLogEvent? = self._player.currentItem.errorLog().events.last as? AVPlayerItemErrorLogEvent
            let msg:String? = log?.errorComment
            // FIXME: How should we present this message?
            self._notify(Statuses.ErrorLog,msg: "Error",obj: log)
        case AVPlayerItemNewAccessLogEntryNotification:
            let log:AVPlayerItemAccessLogEvent? = self._player.currentItem.accessLog().events.last as? AVPlayerItemAccessLogEvent
            self._notify(Statuses.AccessLog,msg: "Access Log",obj: log)
        default:
            true
        }
    }
    
    //----------
    
    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        
        if object as NSObject == self._player {
            switch keyPath {
            case "status":
                switch object.status as AVPlayerStatus {
                case AVPlayerStatus.ReadyToPlay:
                    self._notify(Statuses.PlayerReady, msg: "Player Ready to Play")
                case AVPlayerStatus.Failed:
                    self._notify(Statuses.PlayerFailed,msg: self._player.error.localizedDescription, obj:self._player.error)
                default:
                    true
                }
            case "rate":
                switch object.rate as Float {
                case 0.0:
                    self._notify(Statuses.Paused,msg: "Paused")
                case 1.0:
                    self._notify(Statuses.Playing,msg: "Playing")
                default:
                    // shouldn't get here...
                    true
                }
            default:
                true
            }
        } else if object as NSObject == self._player.currentItem {
            switch object.status as AVPlayerItemStatus {
            case AVPlayerItemStatus.ReadyToPlay:
                self._notify(Statuses.ItemReady,msg:"Item Ready to Play")
            case AVPlayerItemStatus.Failed:
                self._notify(Statuses.ItemFailed, msg: self._player.currentItem.error.localizedDescription, obj: self._player.currentItem.error)
            default:
                NSLog("curItem gave unhandled status")
            }
            
        } else {
            // not sure...
        }
    }
}