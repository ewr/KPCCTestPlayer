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

    public enum Statuses {
        case New, Stopped, Playing, Seeking, Paused, Error

        func toString() -> String {
            switch self {
            case New:
                return "New"
            case Playing:
                return "Playing"
            case Stopped:
                return "Stopped"
            case Paused:
                return "Paused"
            case Seeking:
                return "Seeking"
            case Error:
                return "Error"
            }
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
                case AVObserver.Statuses.PlayerFailed:
                    NSLog("Player failed with error: %@", msg)
                case AVObserver.Statuses.Stalled:
                    NSLog("Playback stalled.")
                case AVObserver.Statuses.AccessLog:
                    NSLog("New access log entry")                    
                case AVObserver.Statuses.ErrorLog:
                    NSLog("New error log entry")
                default:
                    true
                }
            }
            
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
                    if self._seeking {
                        // we don't want to update anything mid-seek
                        return
                    }

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
                    
                    if curDate != nil {                        
                        var status = StreamDates(curDate: curDate, minDate: minDate, maxDate: maxDate)
                        
                        self.currentDates = status
                        
                        for o in self._observers {
                            o(status)
                        }
                        
                        //NSLog("curDate is %@", self._dateFormat.stringFromDate(curDate))
                        
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
        self.getPlayer().play()
        self.playing = true
        self._setStatus(Statuses.Playing)

        return true
    }

    //----------

    public func pause() -> Bool {
        self.getPlayer().pause()
        self.playing = false
        self._setStatus(Statuses.Paused)

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

    public func seekToDate(date: NSDate) -> Bool {
        // do we think we can do this?
        // FIXME: check currentDates if we have them
        NSLog("seekToDate called for %@",self._dateFormat.stringFromDate(date))

        let p = self.getPlayer()
        
        if p.status != AVPlayerStatus.ReadyToPlay {
            // we need to wait for ready before playing or seeking
            return false
        }
//        if !(self.status == Statuses.Playing || self.status == Statuses.Paused) {
//            // hit play and pause to prepare for a seek?
//            p.prerollAtRate(1.0) { finished in
//                NSLog("cold preroll completed. Trying seek.")
//                self.seekToDate(date)
//            }
//            return true
//        }

        self._seeking = true
        self._setStatus(Statuses.Seeking)

        p.currentItem.seekToDate(date, completionHandler: { finished in
            if finished {
                NSLog("seekToDate landed at %@", self._dateFormat.stringFromDate(p.currentItem.currentDate()))
                self._seeking = false
                self._setStatus(Statuses.Playing)
                // FIXME: Need to see if we landed where we should have. If not, try again
            } else {
                NSLog("seekToDate did not finish")
            }


        })

        return true
    }

    //----------

    public func seekToPercent(percent: Float64) -> Bool {
        let p = self.getPlayer()

        var seek_range = p.currentItem.seekableTimeRanges[0].CMTimeRangeValue

        var seek_time = CMTimeAdd( seek_range.start, CMTimeMultiplyByFloat64(seek_range.duration,percent))

        self._seeking = true
        self._setStatus(Statuses.Seeking)
        p.currentItem.seekToTime(seek_time, completionHandler: {(finished:Bool) -> Void in
            if finished {
                NSLog("seekToPercent landed from %2f", percent)
                self._seeking = false
                self._setStatus(Statuses.Playing)
            }


        })

        return true
    }

    //----------

    public func seekToLive(completionHandler:(Bool) -> Void) -> Void {
        let p = self.getPlayer()

        p.currentItem.seekToTime(kCMTimePositiveInfinity) { finished in
            NSLog("Did seekToLive. Landed at %@", self._dateFormat.stringFromDate(p.currentItem.currentDate()))
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