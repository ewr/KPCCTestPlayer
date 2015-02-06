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
    let _player:AVPlayer
    let _callback:( (Statuses,String,AnyObject?) -> Void )
    
    enum Statuses {
        case PlayerFailed, PlayerReady, ItemFailed, ItemReady, Stalled, TimeJump, AccessLog, ErrorLog
    }
    
    let _itemNotifications = [
        AVPlayerItemPlaybackStalledNotification,
        AVPlayerItemTimeJumpedNotification,
        AVPlayerItemNewAccessLogEntryNotification,
        AVPlayerItemNewErrorLogEntryNotification
    ]
    
    init(player:AVPlayer,callback:(Statuses,String,AnyObject?) -> Void) {
        self._player = player
        self._callback = callback
        
        super.init()
        
        player.addObserver(self, forKeyPath:"status", options: nil, context: nil)
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
    
    func item_notification(notification:NSNotification) -> Void {
        switch notification.name {
        case AVPlayerItemPlaybackStalledNotification:
            self._callback(Statuses.Stalled,"Playback Stalled",nil)
        case AVPlayerItemTimeJumpedNotification:
            self._callback(Statuses.TimeJump,"Time jumped.",nil)
        case AVPlayerItemNewErrorLogEntryNotification:
            // try and pull the log...
            let log:AVPlayerItemErrorLogEvent? = self._player.currentItem.errorLog().events.last as? AVPlayerItemErrorLogEvent
            let msg:String? = log?.errorComment
            // FIXME: How should we present this message?
            self._callback(Statuses.ErrorLog,"Error",log)
        case AVPlayerItemNewAccessLogEntryNotification:
            let log:AVPlayerItemAccessLogEvent? = self._player.currentItem.accessLog().events.last as? AVPlayerItemAccessLogEvent
            self._callback(Statuses.AccessLog,"Access Log",log)
        default:
            true
        }
    }
    
    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        
        if object as NSObject == self._player {
            switch object.status as AVPlayerStatus {
            case AVPlayerStatus.Failed:
                let msg = object.error??.localizedDescription ?? "Unknown Error."
                self._callback(Statuses.PlayerFailed,msg,nil)

                true
            default:
                true
            }
        } else if object as NSObject == self._player.currentItem {
            switch object.status as AVPlayerItemStatus {
            case AVPlayerItemStatus.ReadyToPlay:
                self._callback(Statuses.ItemReady,"",nil)
                NSLog("curItem readyToPlay")
                true
            case AVPlayerItemStatus.Failed:
                NSLog("curItem failed.")
                true
            default:
                NSLog("curItem gave unhandled status")
                true
            }
            
        } else {
            // not sure...
        }
    }
}