//
//  AudioPlayer.swift
//  KPCCTestPlayer
//
//  Created by Eric Richardson on 1/12/15.
//  Copyright (c) 2015 Eric Richardson. All rights reserved.
//

import Foundation
import AVFoundation

class AudioPlayer {
    class var sharedInstance: AudioPlayer {
        struct Static {
            static let instance = AudioPlayer()
        }
        return Static.instance
    }
    
    //----------
    
    let STREAM_URL = "http://streammachine-hls001.scprdev.org/sg/kpcc-aac.m3u8"
    
    var _player: AVPlayer?
    
    var playing: Bool
    
    var _timeObserver: AnyObject?
    
    var _dateFormat: NSDateFormatter
    
    struct StreamDates {
        var curDate: NSDate
        var minDate: NSDate?
        var maxDate: NSDate?
    }
    
    var _observers: [(StreamDates) -> Void] = []
    
    init() {
        self.playing = false
        
        self._dateFormat = NSDateFormatter()
        self._dateFormat.dateFormat = "hh:mm:ss a"
    }
    
    func getPlayer() -> AVPlayer {
        if (self._player == nil) {
            self._player = AVPlayer(URL:NSURL(string:self.STREAM_URL))
            
            let av = AVAudioSession.sharedInstance()
            av.setCategory(AVAudioSessionCategoryPlayback, error:nil)
            
            // FIXME: should be checking return here to see if we did go active
            av.setActive(true, error: nil)
            
            // observe time every second
            self._player?.addPeriodicTimeObserverForInterval(CMTimeMake(1,1), queue: nil,
                usingBlock: {(time:CMTime) in
                    var curDate = self._player!.currentItem.currentDate()
                    
                    var seek_range: CMTimeRange
                    var minDate: NSDate? = nil
                    var maxDate: NSDate? = nil
                    
                    if !self._player!.currentItem.seekableTimeRanges.isEmpty {
                        seek_range = self._player!.currentItem.seekableTimeRanges[0].CMTimeRangeValue
                        
                        minDate = NSDate(timeInterval: -1 * (CMTimeGetSeconds(time) - CMTimeGetSeconds(seek_range.start)), sinceDate:curDate)
                        maxDate = NSDate(timeInterval: CMTimeGetSeconds(CMTimeRangeGetEnd(seek_range)) - CMTimeGetSeconds(time), sinceDate:curDate)
                        

                        //NSLog("minDate is %@", self._dateFormat.stringFromDate(minDate))
                        //NSLog("maxDate is %@", self._dateFormat.stringFromDate(maxDate))
                    }
                    
                    var status = StreamDates(curDate: curDate, minDate: minDate, maxDate: maxDate)
                    
                    for o in self._observers {
                        o(status)
                    }
                    
                    NSLog("curDate is %@", self._dateFormat.stringFromDate(curDate))
                }
            )
        }
        
        return self._player!
        
    }
    
    //----------
    
    func observeTime(observer:(StreamDates) -> Void) -> Void {
        self._observers.append(observer)
    }
    
    //----------
    
    func play() -> Bool{
        self.getPlayer().play()
        self.playing = true
        
        return true
    }
    
    //----------
    
    func pause() -> Bool {
        self.getPlayer().pause()
        self.playing = false
    
        return true
    }
    
    //----------
    
    func stop() -> Bool {
        // FIXME: tear down player
        
        return true
    }
    
    //----------
    
    func seekToDate(date: NSDate) -> Bool {
        
        return false
    }
    
    //----------
    
    func seekToPercent(percent: Float64) -> Bool {
        let p = self.getPlayer()
        
        var seek_range = p.currentItem.seekableTimeRanges[0].CMTimeRangeValue
        
        var seek_time = CMTimeAdd( seek_range.start, CMTimeMultiplyByFloat64(seek_range.duration,percent))
        
        p.currentItem.seekToTime(seek_time)
        p.currentItem.seekToTime(seek_time, completionHandler: {(finished:Bool) -> Void in
            if finished {
                NSLog("seekToPercent landed from %2f", percent)
            }
        })
        
        return true
    }
}