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

public class AudioPlayer {
    public class var sharedInstance: AudioPlayer {
        struct Static {
            static let instance = AudioPlayer()
        }
        return Static.instance
    }

    //----------

    public enum Statuses:String {
        case New = "New", Stopped = "Stopped", Playing = "Playing", Waiting = "Waiting", Seeking = "Seeking", Paused = "Paused", Error = "Error"

        func toString() -> String {
            return self.rawValue
        }
    }

    //----------

    let STREAM_URL = "http://streammachine-hls001.scprdev.org/sg/kpcc-aac.m3u8?ua=KPCC-EWRTest"

    let NORMAL_REWIND = 4 * 60 * 60

    var _player: AVPlayer?
    var _pobs: AVObserver?

    var playing: Bool

    var _timeObserver: AnyObject?

    var _dateFormat: NSDateFormatter

    public struct StreamDates {
        var curDate: NSDate
        var minDate: NSDate?
        var maxDate: NSDate?
    }

    var currentDates: StreamDates?

    var _observers: [(StreamDates) -> Void] = []
    var _showObservers: [(Schedule.ScheduleInstance?) -> Void] = []
    var _statusObservers: [(Statuses) -> Void] = []

    var _currentShow: Schedule.ScheduleInstance? = nil
    var _checkingDate: NSDate?
    var _seeking: Bool = false
    
    var _seekSeq:Int = 0
    
    var _sessionId:String?

    var prevStatus: Statuses = Statuses.New
    var status: Statuses = Statuses.New
    
//    class LoaderUAHelper: NSObject, AVAssetResourceLoaderDelegate {
//        let _manager:Alamofire.Manager
//        
//        override init() {
//            var headers = Alamofire.Manager.sharedInstance.session.configuration.HTTPAdditionalHeaders ?? [:]
//            headers["User-Agent"] = "KPCC-EWR 0.1"
//            let config = NSURLSessionConfiguration.defaultSessionConfiguration()
//            config.HTTPAdditionalHeaders = headers
//            
//            self._manager = Alamofire.Manager(configuration:config)
//        }
//        func resourceLoader(resourceLoader: AVAssetResourceLoader!, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest!) -> Bool {
//            
//            // we want to convert the fake proto to http, then do the load
//            let url = NSURLComponents(URL: loadingRequest.request.URL, resolvingAgainstBaseURL: false)
//            
//            if url != nil {
//                url!.scheme = "http"
//                
//                let request = self._manager.request(.GET, url!.string!).response { (req,res,data,err) in
//                    NSLog("request finished: %@",url!.string!)
//                    loadingRequest.response = res
//                    
//                    // set the data
//                    loadingRequest.dataRequest.respondWithData(data as NSData)
//                    
//                    if loadingRequest.contentInformationRequest != nil {
//                        // contentType is a little funky...
//                        if (url!.path!.rangeOfString(".aac") != nil) {
//                            loadingRequest.contentInformationRequest.contentType = "public.aac-audio"
//                        } else if (url!.path!.rangeOfString(".m3u8") != nil) {
//                            loadingRequest.contentInformationRequest.contentType = "public.m3u-playlist"
//                        }
//                    
//                        // data length
//                        loadingRequest.contentInformationRequest.contentLength = data!.length!
//                    }
//                    
//                    // we're done
//                    loadingRequest.finishLoading()
//                }
//                
//                //debugPrintln(request)
//                
//                return true
//            } else {
//                NSLog("failed to figure out request for %@", loadingRequest.request.URL)
//                return false
//            }
//        }
//
//    }
    
    //let _lhelper:LoaderUAHelper

    //----------

    init() {
        self.playing = false

        self._dateFormat = NSDateFormatter()
        self._dateFormat.dateFormat = "hh:mm:ss a"
        
        self._setStatus(.New)
        
        //self._lhelper = LoaderUAHelper()
    }

    //----------

    private func getPlayer() -> AVPlayer {
        if (self._player == nil) {
            let asset = AVURLAsset(URL:NSURL(string:self.STREAM_URL),options:nil)
            //let curDelegate = asset.resourceLoader.delegate
            //asset.resourceLoader.setDelegate(self._lhelper, queue: dispatch_get_main_queue())
            
            let item = AVPlayerItem(asset: asset)
            self._player = AVPlayer(playerItem: item)
            
            // set up an observer for player / item status
            self._pobs = AVObserver(player:self._player!) { status,msg,obj in
                switch status {
                case .PlayerFailed:
                    NSLog("Player failed with error: %@", msg)
                    // FIXME: This is fatal. We need to reset.
                case .Stalled:
                    NSLog("Playback stalled.")
                case .AccessLog:
                    NSLog("New access log entry")                    
                case .ErrorLog:
                    NSLog("New error log entry")
                case .Playing:
                    self._setStatus(.Playing)
                case .Paused:
                    // we pause as part of seeking, so don't pass on that status
                    if self.status != .Seeking {
                        self._setStatus(.Paused)
                    }
                default:
                    true
                }
            }
            
            // grab session id from our first access log
            self._pobs?.once(.AccessLog) { msg,obj in
                // grab session id from the log
                self._sessionId = (obj as AVPlayerItemAccessLogEvent).playbackSessionID
                NSLog("Playback Session ID is %@",self._sessionId!)
            }
            
            let av = AVAudioSession.sharedInstance()
            av.setCategory(AVAudioSessionCategoryPlayback, error:nil)

            // FIXME: should be checking return here to see if we did go active
            av.setActive(true, error: nil)

            // observe time every second
            self._player!.addPeriodicTimeObserverForInterval(CMTimeMake(1,1), queue: nil,
                usingBlock: {(time:CMTime) in
                    if self.status == .Seeking {
                        // we don't want to update anything mid-seek
                        return
                    }

                    var curDate = self._player!.currentItem.currentDate()

                    var seek_range: CMTimeRange
                    var minDate: NSDate? = nil
                    var maxDate: NSDate? = nil

                    if !self._player!.currentItem.seekableTimeRanges.isEmpty {
                        seek_range = self._player!.currentItem.seekableTimeRanges[0].CMTimeRangeValue

                        // these calculations assume no discontinuities in the playlist data
                        minDate = NSDate(timeInterval: -1 * (CMTimeGetSeconds(time) - CMTimeGetSeconds(seek_range.start)), sinceDate:curDate)
                        maxDate = NSDate(timeInterval: CMTimeGetSeconds(CMTimeRangeGetEnd(seek_range)) - CMTimeGetSeconds(time), sinceDate:curDate)
                    }
                    
                    if curDate != nil {                        
                        var status = StreamDates(curDate: curDate, minDate: minDate, maxDate: maxDate)
                        
                        self.currentDates = status
                        
                        for o in self._observers {
                            o(status)
                        }
                        
                        self._checkForNewShow(curDate, from_seek:false)
                    }

                }
            )
        }

        return self._player!

    }
    
    //----------

    //----------

    private func _setStatus(s:Statuses) -> Void {
        if !(self.status == s) {
            self.prevStatus = self.status
            self.status = s
            
            for o in self._statusObservers {
                o(s)
            }
        }
    }

    //----------

    public func observeTime(observer:(StreamDates) -> Void) -> Void {
        self._observers.append(observer)
    }

    //----------

    public func onShowChange(observer:(Schedule.ScheduleInstance?) -> Void) -> Void {
        self._showObservers.append(observer)
    }

    //----------

    public func onStatusChange(observer:(Statuses) -> Void) -> Void {
        self._statusObservers.append(observer)
    }

    //----------

    public func play() -> Bool{
        self._setStatus(.Waiting)
        self.getPlayer().play()
        return true
    }

    //----------

    public func pause() -> Bool {
        self._setStatus(.Waiting)
        self.getPlayer().pause()
        return true
    }

    //----------

    public func stop() -> Bool {
        // FIXME: tear down player

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
        
        if useTime {
            // compute difference between currentTime and the time we want, and then use seekToTime
            // to try and get there
            
            let offsetSeconds = date.timeIntervalSinceReferenceDate - p.currentItem.currentDate().timeIntervalSinceReferenceDate
            let seek_time = CMTimeAdd(p.currentItem.currentTime(), CMTimeMakeWithSeconds(offsetSeconds, 1))
            
            p.currentItem.seekToTime(seek_time, completionHandler: { finished in
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
        
        p.currentItem.seekToTime(seek_time, completionHandler: {(finished:Bool) -> Void in
            if finished {
                NSLog("seekToPercent landed from %2f", percent)
                p.play()
            }
        })

        return true
    }

    //----------

    public func seekToLive(completionHandler:(Bool) -> Void) -> Void {
        let p = self.getPlayer()
        
        if p.rate != 0.0 {
            p.pause()
        }

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

                // update any observers
                for o in self._showObservers {
                    o(show)
                }
            }
        }

    }
}