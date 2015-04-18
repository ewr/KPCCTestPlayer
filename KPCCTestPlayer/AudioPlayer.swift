//
//  AudioPlayer.swift
//  KPCCTestPlayer
//
//  Created by Eric Richardson on 1/12/15.
//  Copyright (c) 2015 Eric Richardson. All rights reserved.
//

import Foundation
import AVFoundation
import Alamofire
import MobileCoreServices

public struct AudioPlayerObserver<T> {
    var observers: [(T) -> Void] = []
    
    public mutating func addObserver(o:(T) -> Void) {
        observers.append(o)
    }
    
    func notify(obj:T) {
        for o in observers {
            o(obj)
        }
    }
}

//----------

public class AudioPlayer {
    public static let sharedInstance = AudioPlayer()

    //----------

    public enum Statuses:String {
        case New = "New", Stopped = "Stopped", Playing = "Playing", Waiting = "Waiting", Seeking = "Seeking", Paused = "Paused", Error = "Error"

        func toString() -> String {
            return self.rawValue
        }
    }
    
    //----------
    
    public struct Event {
        public var message:String
        public var time:NSDate
    }
    
    //----------
    
    public enum Streams:String {
        case Production = "http://live.scpr.org/sg/kpcc-aac.m3u8?ua=KPCC-EWRTest"
        case Testing    = "http://streammachine-test.scprdev.org/sg/kpcc-aac.m3u8?ua=KPCC-EWRTest"
        
        func toString() -> String {
            return self.rawValue
        }
    }
    
    public typealias finishCallback = (Bool) -> Void
    
    //----------

    let NORMAL_REWIND = 4 * 60 * 60

    var _player: AVPlayer?
    var _pobs: AVObserver?

    var playing: Bool

    var _timeObserver: AnyObject?

    var _dateFormat: NSDateFormatter

    public struct StreamDates {
        var curDate:    NSDate
        var minDate:    NSDate?
        var maxDate:    NSDate?
        var buffered:   Double?
    }

    var currentDates: StreamDates?
    
    //----------

    public var oTime        = AudioPlayerObserver<StreamDates>()
    public var oShow        = AudioPlayerObserver<Schedule.ScheduleInstance?>()
    public var oStatus      = AudioPlayerObserver<Statuses>()
    public var oAccessLog   = AudioPlayerObserver<AVPlayerItemAccessLogEvent>()
    public var oErrorLog    = AudioPlayerObserver<AVPlayerItemErrorLogEvent>()
    public var oEventLog    = AudioPlayerObserver<Event>()

    var _currentShow: Schedule.ScheduleInstance? = nil
    var _checkingDate: NSDate?
    var _seeking: Bool = false
    
    // FIXME: Can this be replaced by the interactionIdx?
    var _seekSeq:Int = 0
    
    var _sessionId:String?
    
    var _lowBandwidth:Bool = false

    var prevStatus: Statuses = Statuses.New
    var status: Statuses = Statuses.New
    
    var _mode:Streams = .Production
    var _wasInterrupted:Bool = false
    
    var _interactionIdx:Int = 0
    
    //let _assetLoader = AudioPlayerAssetLoader()
    let _reachability = Reachability.reachabilityForInternetConnection()

    //----------

    init() {
        self.playing = false

        self._dateFormat = NSDateFormatter()
        self._dateFormat.dateFormat = "hh:mm:ss a"
        
        self._setStatus(.New)
        
        // -- watch for interruptions -- //
        
        NSNotificationCenter.defaultCenter().addObserverForName(AVAudioSessionInterruptionNotification, object: nil, queue: NSOperationQueue.mainQueue()) { n in
            // FIXME: You can't tell me there isn't a cleaner way to do this...
            switch AVAudioSessionInterruptionType( rawValue: n.userInfo![AVAudioSessionInterruptionTypeKey] as! UInt)! {
            case .Began:
                NSLog("Player interruption began. State was \(self.status.toString())")
                
                // this is a little bit of a hack... we want prevStatus to be our current status 
                // when we return from the interruption, but if we're already paused we might not 
                // get it set the normal way.
                self.prevStatus = self.status
                
                true
            case .Ended:
                // should we resume?
                
                let opts = AVAudioSessionInterruptionOptions( n.userInfo![AVAudioSessionInterruptionOptionKey] as! UInt )

                if opts == .OptionShouldResume {
                    NSLog("Told we should resume. Previous status was \(self.prevStatus.toString())")
                    if self.prevStatus == .Playing {
                        if self.currentDates != nil {
                            self.seekToDate(self.currentDates!.curDate,useTime:true)
                        } else {
                            self.play()
                        }
                    }
                }
            default:
                // there are only two cases...
                true
            }
        }
        
        // -- watch for Reachability -- //
        
        switch self._reachability.currentReachabilityStatus {
        case .ReachableViaWiFi:
            NSLog("Init reach is WIFI")
        case .ReachableViaWWAN:
            NSLog("Init reach is cellular")
        case .NotReachable:
            NSLog("Init is unreachable")
        }
        
        self._reachability.whenReachable = { r in
            if r.isReachableViaWiFi() {
                println("Reachable via WiFi")
            } else {
                println("Reachable via Cellular")
            }
        }
        
        self._reachability.whenUnreachable = { r in
            println("Not reachable")
        }
        
        self._reachability.startNotifier()
    }

    //----------

    private func getPlayer() -> AVPlayer {
        if (self._player == nil) {
            NSLog("Creating new Audio Player instance for stream \(self._mode.toString())")
            self._emitEvent("New player instance created for stream \(self._mode.toString())")
            
            let asset = AVURLAsset(URL:NSURL(string:self._mode.toString()),options:nil)
            //asset.resourceLoader.setDelegate(self._assetLoader, queue: self._assetLoader.queue)
            
            let item = AVPlayerItem(asset: asset)
            self._player = AVPlayer(playerItem: item)
            
            // set up an observer for player / item status
            self._pobs = AVObserver(player:self._player!) { status,msg,obj in
                self._emitEvent(msg)
                
                switch status {
                case .PlayerFailed:
                    NSLog("Player failed with error: %@", msg)
                    self.stop()
                case .ItemFailed:
                    let err = obj as! NSError
                    NSLog("Item failed with error: \(msg)")
                    self.stop()
                case .Stalled:
                    NSLog("Playback stalled at \(self._dateFormat.stringFromDate(self.currentDates!.curDate)).")
                    
                    // stash our stall position and interaction index, so that we can 
                    // try to resume in the same spot when we see connectivity return
                    let stallIdx = self._interactionIdx
                    let stallPosition = self.currentDates?.curDate
                    
                    self._pobs!.once(.LikelyToKeepUp) { msg,obj in
                        // if there's been a user interaction in the meantime, we do a no-op
                        if stallIdx == self._interactionIdx {
                            NSLog("trying to resume playback at stall position.")
                            if stallPosition != nil {
                                self.seekToDate(stallPosition!,useTime:true)
                            } else {
                                self._player!.play()
                            }
                        }
                    }
                case .AccessLog:
                    let log = obj as! AVPlayerItemAccessLogEvent
                    NSLog("New access log entry: indicated:\(log.indicatedBitrate) -- switch:\(log.switchBitrate) -- stalls: \(log.numberOfStalls)")
                    
                    self.oAccessLog.notify(log)
                case .ErrorLog:
                    let log = obj as! AVPlayerItemErrorLogEvent
                    NSLog("New error log entry \(log.errorStatusCode): \(log.errorComment)")
                    
                    self.oErrorLog.notify(log)
                case .Playing:
                    self._setStatus(.Playing)
                case .Paused:
                    // we pause as part of seeking, so don't pass on that status
                    if self.status != .Seeking {
                        self._setStatus(.Paused)
                    }
                case .LikelyToKeepUp:
                    NSLog("playback should keep up")
                case .UnlikelyToKeepUp:
                    NSLog("playback unlikely to keep up")
                case .TimeJump:
                    NSLog("Player reports that time jumped.")
                default:
                    true
                }
            }
            
            // grab session id from our first access log
            self._pobs?.once(.AccessLog) { msg,obj in
                // grab session id from the log
                self._sessionId = (obj as! AVPlayerItemAccessLogEvent).playbackSessionID
                self._emitEvent("Playback session ID is \(self._sessionId)")
                NSLog("Playback Session ID is %@",self._sessionId!)
            }
            
            let av = AVAudioSession.sharedInstance()
            av.setCategory(AVAudioSessionCategoryPlayback, error:nil)

            // FIXME: should be checking return here to see if we did go active
            av.setActive(true, error: nil)

            // observe time every second
            self._player!.addPeriodicTimeObserverForInterval(CMTimeMake(1,1), queue: nil,
                usingBlock: {(time:CMTime) in
                    // make sure we didn't happen to get fired while player is getting removed
                    if self._player == nil {
                        return
                    }
                    
                    if self.status == .Seeking {
                        // we don't want to update anything mid-seek
                        return
                    }

                    var curDate = self._player!.currentItem.currentDate()

                    var seek_range: CMTimeRange
                    var minDate: NSDate? = nil
                    var maxDate: NSDate? = nil
                    var buffered: Double? = nil
                    
                    if !self._player!.currentItem.loadedTimeRanges.isEmpty {
                        let loaded_range = self._player!.currentItem.loadedTimeRanges[0].CMTimeRangeValue
                        buffered = CMTimeGetSeconds(CMTimeSubtract(CMTimeRangeGetEnd(loaded_range), time))
                    }

                    if !self._player!.currentItem.seekableTimeRanges.isEmpty {
                        seek_range = self._player!.currentItem.seekableTimeRanges[0].CMTimeRangeValue

                        // these calculations assume no discontinuities in the playlist data
                        // FIXME: We really want to get these from the playlist... There has to be a way to get there
                        minDate = NSDate(timeInterval: -1 * (CMTimeGetSeconds(time) - CMTimeGetSeconds(seek_range.start)), sinceDate:curDate)
                        maxDate = NSDate(timeInterval: CMTimeGetSeconds(CMTimeRangeGetEnd(seek_range)) - CMTimeGetSeconds(time), sinceDate:curDate)
                    }
                    
                    if curDate != nil {                        
                        var status = StreamDates(curDate: curDate, minDate: minDate, maxDate: maxDate, buffered:buffered)
                        
                        self.currentDates = status
                        
                        self.oTime.notify(status)
                        
                        self._checkForNewShow(curDate, from_seek:false)
                    }
                }
            )
        }

        return self._player!

    }
    
    //----------
    
    public func bufferedSecs() -> Double? {
        if ( self._player != nil && !self._player!.currentItem.loadedTimeRanges.isEmpty ) {
            let loaded_range = self._player!.currentItem.loadedTimeRanges[0].CMTimeRangeValue
            let buffered = CMTimeGetSeconds(CMTimeSubtract(CMTimeRangeGetEnd(loaded_range), self._player!.currentTime()))
            
            return buffered
        } else {
            return nil
        }
    }

    //----------
    
    private func _emitEvent(msg:String) -> Void {
        let event = Event(message: msg, time: NSDate())
        self.oEventLog.notify(event)
    }
    
    //----------

    private func _setStatus(s:Statuses) -> Void {
        if !(self.status == s) {
            self.prevStatus = self.status
            self.status = s
            
            self._emitEvent("Player status is now \(s.toString())")
            self.oStatus.notify(s)
        }
    }
    
    //----------
    
    public func getAccessLog() -> AVPlayerItemAccessLog? {
        if self._player != nil {
            return self._player!.currentItem.accessLog()
        } else {
            return nil
        }
    }
    
    //----------
    
    public func getErrorLog() -> AVPlayerItemErrorLog? {
        if self._player != nil {
            return self._player!.currentItem.errorLog()
        } else {
            return nil
        }
    }

    //----------
    
    public func setMode(mode:Streams) -> Void {
        if self._mode == mode {
            // no change
            return
        }
        
        // to change modes we need to tear down the current player
        self.stop()
        
        // and finally set our new mode
        self._mode = mode
    }
    
    public func getMode() -> Streams {
        return self._mode
    }

    //----------

    public func play() -> Bool{
        self._interactionIdx++
        self._setStatus(.Waiting)
        self.getPlayer().play()
        return true
    }

    //----------

    public func pause() -> Bool {
        self._interactionIdx++
        self._setStatus(.Waiting)
        self.getPlayer().pause()
        return true
    }

    //----------

    public func stop() -> Bool {
        // tear down player and observer
        self.pause()
        self._pobs?.stop()
        self._player = nil

        self.currentDates = nil
        self._setStatus(Statuses.Stopped)

        return true
    }

    //----------

    public func seekToDate(date: NSDate,retries:Int = 3,useTime:Bool = false) -> Bool {
        // do we think we can do this?
        // FIXME: check currentDates if we have them
        NSLog("seekToDate called for %@",self._dateFormat.stringFromDate(date))
        
        // get a seek sequence number
        let seek_id = ++self._seekSeq

        let p = self.getPlayer()
        
        if p.status != AVPlayerStatus.ReadyToPlay {
            // we need to wait for ready before playing or seeking
            NSLog("Waiting for player ReadyToPlay")
            self._pobs?.once(.ItemReady) { msg,obj in
                NSLog("Should be ready to play...")
                
                if self._seekSeq == seek_id {
                    // a cold seek with seekToDate never works, so start with seekToTime
                    self.seekToDate(date,useTime:true)
                    return Void()
                }
            }
            
            return false
        }

        self._setStatus(.Seeking)

        // we'll pause, seek, then play
        if p.rate != 0.0 {
            NSLog("Pausing to seek")
            p.pause()
        }
        
        self._interactionIdx++
        
        if useTime {
            // compute difference between currentTime and the time we want, and then use seekToTime
            // to try and get there
            
            let offsetSeconds = date.timeIntervalSinceReferenceDate - p.currentItem.currentDate().timeIntervalSinceReferenceDate
            let seek_time = CMTimeAdd(p.currentItem.currentTime(), CMTimeMakeWithSeconds(offsetSeconds, 1))
            
            p.currentItem.seekToTime(seek_time, toleranceBefore:kCMTimeZero, toleranceAfter:kCMTimeZero, completionHandler: { finished in
                if finished {
                    NSLog("seekToDate (time) landed at %@", self._dateFormat.stringFromDate(p.currentItem.currentDate()))
                    p.play()
                } else {
                    NSLog("seekToDate (time) did not finish")
                }
            })
            
        } else {
            // use seekToDate
            
            p.currentItem.seekToDate(date, completionHandler: { finished in
                if finished {
                    NSLog("seekToDate landed at %@", self._dateFormat.stringFromDate(p.currentItem.currentDate()))
                    self._seeking = false
                    
                    // FIXME: Need to see if we landed where we should have. If not, try again
                    
                    // start playing
                    p.play()
                } else {
                    NSLog("seekToDate did not finish")
                    
                    // if we get here, but our seek_id is still the current one, we should retry. If 
                    // id has changed, there's another seek operation started and we should stop
                    if self._seekSeq == seek_id {
                        switch retries {
                        case 0:
                            NSLog("seekToDate is out of retries")

                        case 1:
                            self.seekToDate(date, retries: retries-1, useTime:true)
                        default:
                            self.seekToDate(date, retries: retries-1)
                        }
                    }
                }
            })
        }

        return true
    }

    //----------

    public func seekToPercent(percent: Float64) -> Bool {
        let p = self.getPlayer()

        var seek_range = p.currentItem.seekableTimeRanges[0].CMTimeRangeValue

        var seek_time = CMTimeAdd( seek_range.start, CMTimeMultiplyByFloat64(seek_range.duration,percent))

        self._setStatus(.Seeking)
        
        if p.rate != 0.0 {
            p.pause()
        }
        
        self._interactionIdx++
        
        p.currentItem.seekToTime(seek_time, completionHandler: {(finished:Bool) -> Void in
            if finished {
                NSLog("seekToPercent landed from %2f", percent)
                p.play()
            }
        })

        return true
    }

    //----------

    public func seekToLive(completionHandler:finishCallback) -> Void {
        let p = self.getPlayer()
        
        if p.status != AVPlayerStatus.ReadyToPlay {
            // we need to wait for ready before playing or seeking
            NSLog("Waiting for player ReadyToPlay")
            self._pobs?.once(.ItemReady) { msg,obj in
                NSLog("Seeking now that player is ready.")
                self.seekToLive(completionHandler)
            }
            
            return
        }
        
        if p.rate != 0.0 {
            p.pause()
        }
        
        self._interactionIdx++

        p.currentItem.seekToTime(kCMTimePositiveInfinity) { finished in
            NSLog("Did seekToLive. Landed at %@", self._dateFormat.stringFromDate(p.currentItem.currentDate()))
            p.play()
            
            completionHandler(finished)
        }
    }

    //----------

    private func _checkForNewShow(date:NSDate,from_seek:Bool = false) -> Void {
        if self._currentShow != nil && (
            (date.timeIntervalSinceReferenceDate >= self._currentShow!.starts_at.timeIntervalSinceReferenceDate)
            && (date.timeIntervalSinceReferenceDate < self._currentShow!.ends_at.timeIntervalSinceReferenceDate)
        ) {
            // we're still in our current show... no change
            return
        }

        // we either don't have a current show, or we're no longer inside it

        if self._checkingDate != nil && !from_seek {
            // we don't interrupt for normal ticks
            return
        }

        // we should fetch for our new time
        self._checkingDate = date

        Schedule.sharedInstance.at(date) { show in
            // make sure a different fetch didn't fire while we were waiting
            if self._checkingDate == date {
                self._currentShow = show
                self._checkingDate = nil

                if show != nil {
                    NSLog("Current show is %@",self._currentShow!.title)
                } else {
                    NSLog("_checkForNewShow failed to get show")
                }

                self.oShow.notify(show)
            }
        }

    }
}