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
    let _callback:( (Statuses,String) -> Void )
    
    enum Statuses {
        case PlayerFailed, PlayerReady, ItemFailed, ItemReady
    }
    
    init(player:AVPlayer,callback:(Statuses,String) -> Void) {
        self._player = player
        self._callback = callback
        
        super.init()
        
        player.addObserver(self, forKeyPath:"status", options: nil, context: nil)
        player.currentItem.addObserver(self, forKeyPath:"status", options: nil, context: nil)
    }
    
    //----------
    
    func stop() {
        
    }
    
    //----------
    
    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<Void>) {
        
        if object as NSObject == self._player {
            switch object.status as AVPlayerStatus {
            case AVPlayerStatus.Failed:
                let msg = object.error??.localizedDescription ?? "Unknown Error."
                self._callback(Statuses.PlayerFailed,msg)

                true
            default:
                true
            }
        } else if object as NSObject == self._player.currentItem {
            switch object.status as AVPlayerItemStatus {
            case AVPlayerItemStatus.ReadyToPlay:
                self._callback(Statuses.ItemReady,"")
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