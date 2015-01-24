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

    enum Statuses {
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

    var playing: Bool

    var _timeObserver: AnyObject?

    var _dateFormat: NSDateFormatter

    struct StreamDates {
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

    var prevStatus: Statuses = Statuses.New
    var status: Statuses = Statuses.New

    //----------

    init() {
        self.playing = false

        self._dateFormat = NSDateFormatter()
        self._dateFormat.dateFormat = "hh:mm:ss a"


    }

    //----------

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

    func observeTime(observer:(StreamDates) -> Void) -> Void {
        self._observers.append(observer)
    }

    //----------

    func onShowChange(observer:(Schedule.ScheduleInstance?) -> Void) -> Void {
        self._showObservers.append(observer)
    }

    //----------

    func onStatusChange(observer:(Statuses) -> Void) -> Void {
        self._statusObservers.append(observer)
    }

    //----------

    func play() -> Bool{
        self.getPlayer().play()
        self.playing = true
        self._setStatus(Statuses.Playing)

        return true
    }

    //----------

    func pause() -> Bool {
        self.getPlayer().pause()
        self.playing = false
        self._setStatus(Statuses.Paused)

        return true
    }

    //----------

    func stop() -> Bool {
        // FIXME: tear down player

        self.currentDates = nil
        self._setStatus(Statuses.Stopped)

        return true
    }

    //----------

    func seekToDate(date: NSDate) -> Bool {
        // do we think we can do this?
        // FIXME: check currentDates if we have them
        NSLog("seekToDate called for %@",self._dateFormat.stringFromDate(date))

        let p = self.getPlayer()

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

    func seekToPercent(percent: Float64) -> Bool {
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

    func _checkForNewShow(date:NSDate,from_seek:Bool = false) -> Void {
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