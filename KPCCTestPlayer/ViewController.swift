//
//  ViewController.swift
//  KPCCTestPlayer
//
//  Created by Eric Richardson on 1/6/15.
//  Copyright (c) 2015 Eric Richardson. All rights reserved.
//

import UIKit
import MediaPlayer

class ViewController: UIViewController {
    @IBOutlet weak var timeDisplay: UILabel!
    @IBOutlet weak var playPauseButton: UIButton!
    @IBOutlet weak var progressSlider: UISlider!
    @IBOutlet weak var showLabel: UILabel!
    @IBOutlet weak var showTimes: UILabel!
    @IBOutlet weak var rewindButton: UIButton!
    @IBOutlet weak var liveButton: UIButton!
    
    @IBOutlet weak var sliderMode: UISwitch!
    @IBOutlet weak var variantLabel: UILabel!
    @IBOutlet weak var bufferLabel: UILabel!
    @IBOutlet weak var limitBandwidth: UISwitch!
    
    var currentShow:Schedule.ScheduleInstance?
    var playingShow:Schedule.ScheduleInstance?
    
    struct NowPlayingInfo {
        var title:String                = ""
        var is_playing:Bool             = false
        var show_duration:Double        = 0.0
        var current_duration:Double     = 0.0
        var current_time:String?        = nil
    }
    
    let _timeF = NSDateFormatter()
    let _dateF = NSDateFormatter()
    
    var nowPlaying:NowPlayingInfo?
    
    var _lastM:String?
    
    var _bufferTimer:NSTimer?
    
    var _sliderInPreview:Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()

        // disable the slider initially until we have a working player
        self.progressSlider.enabled = false
        self.sliderMode.enabled = false

        self.limitBandwidth.enabled = true
        self.limitBandwidth.on = false
        
        self.nowPlaying = NowPlayingInfo()
        
        self.playPauseButton.addTarget(self, action: "playPauseTapped:", forControlEvents: UIControlEvents.TouchUpInside)
        self.rewindButton.addTarget(self, action: "rewindTapped:", forControlEvents: UIControlEvents.TouchUpInside)
        self.liveButton.addTarget(self, action: "liveTapped:", forControlEvents: UIControlEvents.TouchUpInside)

        self.progressSlider.addTarget(self, action: "sliderPreview:", forControlEvents: UIControlEvents.ValueChanged)
        self.progressSlider.addTarget(self, action: "sliderUpdated:", forControlEvents: UIControlEvents.TouchUpInside)
        self.progressSlider.addTarget(self, action: "sliderUpdated:", forControlEvents: UIControlEvents.TouchUpOutside)

        self.limitBandwidth.addTarget(self, action: "limitUpdated:", forControlEvents: UIControlEvents.ValueChanged)
        
        self._dateF.dateFormat = "YYYY-MM-dd hh:mm:ss"
        self._timeF.dateFormat = "h:mma"

        //---

        AudioPlayer.sharedInstance.oTime.addObserver() { (status:AudioPlayer.StreamDates) -> Void in
            // set current time display
            if !self._sliderInPreview {
                self._updateTimeDisplay(status.curDate)

                // set slider
                if status.minDate != nil {
                    self._setSlider(status)
                }
            }

            
            let curM = self._timeF.stringFromDate(status.curDate)
            
            if (self._lastM == nil || curM != self._lastM) {
                if (self.playingShow != nil) {
                    let title = self.playingShow!.title + " (" + curM + ")"
                    self.nowPlaying!.title = title
                    self.nowPlaying!.current_duration = Double(status.curDate.timeIntervalSinceReferenceDate - self.playingShow!.starts_at.timeIntervalSinceReferenceDate)
                    
                    self._updateNowPlaying()
                    self._lastM = curM
                }
            }
        }

        // -- set show change observer -- #
        
        // AudioPlayer will tell us when the playhead crosses into a new show

        AudioPlayer.sharedInstance.oShow.addObserver() { show in
            self.setShowInfoFromShow(show)
            self.playingShow = show
            
            // set show duration
            if show != nil {
                let secs = show!.ends_at.timeIntervalSinceReferenceDate - show!.starts_at.timeIntervalSinceReferenceDate
                self.nowPlaying!.show_duration = Double(secs)
            }
        }
        
        //---
        
        AudioPlayer.sharedInstance.oStatus.addObserver() { status in
            NSLog("view player status is %@",status.toString())
            
            switch status {
            case .New:
                // do nothing. default UI state
                true
            case .Waiting:
                // we're mid-operation... disable UI
                NSLog("View got waiting state")
            case .Playing:
                // set up for remote events
                self.becomeFirstResponder()
                UIApplication.sharedApplication().beginReceivingRemoteControlEvents()
                
                self.nowPlaying?.is_playing = true
                self._updateNowPlaying()
            case .Stopped, .Paused:
                self.nowPlaying?.is_playing = false
                self._updateNowPlaying()
                
                // clear variant display
                self.variantLabel.text = "---"
            default:
                // we don't care?
                true
            }
        }
        
        // -- set play/pause button state -- //
        
        AudioPlayer.sharedInstance.oStatus.addObserver() { status in
            switch status {
            case .Playing:
                // show pause button
                self.playPauseButton.setTitle("Pause", forState: .Normal)
            case .Waiting:
                // FIXME: disable UI temporarily
                self.playPauseButton.setTitle("---", forState: .Normal)
            default:
                // show the play button
                self.playPauseButton.setTitle("Play", forState: .Normal)
            }
        }
        
        // -- set slider state -- //
        
        AudioPlayer.sharedInstance.oStatus.addObserver() { status in
            switch status {
            case .New, .Stopped:
                self.progressSlider.enabled = false
                self.sliderMode.enabled = false
            default:
                self.progressSlider.enabled = true
                self.sliderMode.enabled = true
            }
        }
        
        // -- load information for what's on now -- //
        
        // this is during init, before we actually launch a player and get a show 
        // change that way.
        
        Schedule.sharedInstance.at(NSDate()) { show in
            self.setShowInfoFromShow(show)
            self.currentShow = show
        }
        
        // -- set up timer for buffered seconds -- //
        
        self._bufferTimer = NSTimer.scheduledTimerWithTimeInterval(1, target:self, selector:"_updateBufferLabel", userInfo:nil, repeats:true)
        
        // -- watch for variant changes -- //
        
        AudioPlayer.sharedInstance.oAccessLog.addObserver() { log in
            let kbrate = String(format:"%d",Int(log.indicatedBitrate / 1000))
            
            
            self.variantLabel.text = "\(kbrate)kb"
        }
    }
    
    //----------
    
    override func remoteControlReceivedWithEvent(event: UIEvent?) {
        switch event!.subtype {
        case UIEventSubtype.RemoteControlPlay:
            AudioPlayer.sharedInstance.play()
        case UIEventSubtype.RemoteControlPause:
            AudioPlayer.sharedInstance.pause()
        case UIEventSubtype.RemoteControlStop:
            AudioPlayer.sharedInstance.stop()
        default:
            // unhandled...
            true
        }
    }

    //----------

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    //----------
    
    func _updateBufferLabel() {
        
        var value:String = "---"
        
        switch AudioPlayer.sharedInstance.status {
        case .Playing, .Paused, .Waiting:
            // update
            let buffer = AudioPlayer.sharedInstance.bufferedSecs()
            
            if buffer != nil {
                value = "\(round(buffer!))"
            } else {
                value = "???"
            }
        default:
            // reset to blank
            true
        }
        
        self.bufferLabel.text = value
    }
    
    //----------
    
    func _updateNowPlaying() -> Void {
        MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo = [
            MPMediaItemPropertyTitle:                       self.nowPlaying!.title,
            MPMediaItemPropertyArtist:                      "89.3 KPCC",
            MPNowPlayingInfoPropertyPlaybackRate:           (self.nowPlaying!.is_playing ? 1.0 : 0.0),
            MPMediaItemPropertyPlaybackDuration:            self.nowPlaying!.show_duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime:    self.nowPlaying!.current_duration,
        ]
    }
    
    //----------
    
    func _updateTimeDisplay(date:NSDate?) -> Void {
        var val:String
        
        if date != nil {
            val = self._dateF.stringFromDate(date!)
        } else {
            val = "---"
        }
        
        self.timeDisplay.text = val
    }
    
    //----------
    
    func setShowInfoFromShow(show:Schedule.ScheduleInstance?) -> Void {
        if show != nil {
            self.showLabel.text = show!.title
            self.showTimes.text =
                self._timeF.stringFromDate(show!.starts_at) + " - " + self._timeF.stringFromDate(show!.ends_at)
            
            self.nowPlaying?.title = show!.title
            self._updateNowPlaying()
            
        } else {
            self.showLabel.text = "????"
            self.showTimes.text = ""
            
            self.nowPlaying?.title = ""
            self._updateNowPlaying()
        }
    }
    
    //----------

    func playPauseTapped(sender:UIButton!) {
        let ap = AudioPlayer.sharedInstance
        
        switch ap.status {
        case .Playing:
            ap.pause()
        case .Paused, .New, .Stopped:
            ap.play()
        default:
            NSLog("Unsure of play/pause action to take from %@",ap.status.toString())
        }
    }
    
    //----------
    
    func liveTapped(sender:UIButton!) {
        let ap = AudioPlayer.sharedInstance
        ap.seekToLive() { finished in
            NSLog("finished is %@",finished)
        }
    }

    //----------

    func rewindTapped(sender:UIButton!) {
        let ap = AudioPlayer.sharedInstance

        // if we're playing a show, use that...
        if ap._currentShow != nil {
            ap.seekToDate(ap._currentShow!.soft_starts_at)
            return
        }
        
        // otherwise, if we have a currently-scheduled show, use that
        if self.currentShow != nil {
            ap.seekToDate(self.currentShow!.soft_starts_at)
        }
    }

    //----------
    
    func _setSlider(status:AudioPlayer.StreamDates) -> Void {
        switch self.sliderMode.on {
        case true:
            // slider should display information for this program
            if self.playingShow != nil {
                let show = self.playingShow!
                
                var duration:Double
                
//                if (status.maxDate != nil && status.maxDate!.timeIntervalSince1970 < show.ends_at.timeIntervalSince1970) {
//                    duration = status.maxDate!.timeIntervalSince1970 - show.starts_at.timeIntervalSince1970
//                } else {
                    duration = show.ends_at.timeIntervalSince1970 - show.starts_at.timeIntervalSince1970
//                }
                
                let position:Double = status.curDate.timeIntervalSince1970 - show.starts_at.timeIntervalSince1970
                
                let percent = position / duration
                
                self.progressSlider.value = Float(percent)
            }
            
        default:
            // slider should display entire buffer
            let duration: Double = status.maxDate!.timeIntervalSince1970 - status.minDate!.timeIntervalSince1970
            let position: Double = status.curDate.timeIntervalSince1970 - status.minDate!.timeIntervalSince1970
            
            let percent = position / duration
            
            self.progressSlider.value = Float(percent)
        }
    }
    
    //----------
    
    func sliderPreview(sender:UISlider) {
        let fpercent = Float64(sender.value)
        
        // note that we're previewing, so that other UI updates don't happen
        self._sliderInPreview = true
        
        var date:NSDate?
        
        switch self.sliderMode.on {
        case true:
            // seek to percentage in the current program
            if self.playingShow != nil {
                date = self.playingShow!.percentToDate(fpercent)
            }
            
        default:
            // seek to percentage in the buffer
            let dates = AudioPlayer.sharedInstance.currentDates
            
            if dates != nil {
                date = dates!.percentToDate(fpercent)
            }
        }
        
        self._updateTimeDisplay(date)
    }

    func sliderUpdated(sender:UISlider) {
        let fpercent = Float64(sender.value)
        
        self._sliderInPreview = false
        
        switch self.sliderMode.on {
        case true:
            // seek to percentage in the current program
            if self.playingShow != nil {
                let date = self.playingShow!.percentToDate(fpercent)
                
                if date != nil {
                    AudioPlayer.sharedInstance.seekToDate(date!)
                }
            }
            
        default:
            // seek to percentage in the buffer
            AudioPlayer.sharedInstance.seekToPercent(fpercent)
        }
    }

    //----------

    func limitUpdated(sender:UISwitch) {
        AudioPlayer.sharedInstance.reduceAllBandwidth = sender.on
    }

}

