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
    @IBOutlet weak var scheduleTable: UITableView!
    @IBOutlet weak var showLabel: UILabel!
    @IBOutlet weak var showTimes: UILabel!
    @IBOutlet weak var rewindButton: UIButton!
    
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
    
    var nowPlaying:NowPlayingInfo?
    
    var _lastM:String?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.nowPlaying = NowPlayingInfo()
        
        self.playPauseButton.addTarget(self, action: "playPauseTapped:", forControlEvents: UIControlEvents.TouchUpInside)
        self.progressSlider.addTarget(self, action: "sliderUpdated:", forControlEvents: UIControlEvents.ValueChanged)
        self.rewindButton.addTarget(self, action: "rewindTapped:", forControlEvents: UIControlEvents.TouchUpInside)

        var formatter = NSDateFormatter()
        formatter.dateFormat = "YYYY-MM-DD hh:mm:ss"

        self._timeF.dateFormat = "h:mma"

        //---

        AudioPlayer.sharedInstance.observeTime() { (status:AudioPlayer.StreamDates) -> Void in
            // set current time display
            self.timeDisplay.text = formatter.stringFromDate(status.curDate)

            // set slider
            if status.minDate != nil {
                var duration: Double = status.maxDate!.timeIntervalSince1970 - status.minDate!.timeIntervalSince1970
                var position: Double = status.curDate.timeIntervalSince1970 - status.minDate!.timeIntervalSince1970

                var percent = position / duration

                self.progressSlider.value = Float(percent)
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

        //---

        AudioPlayer.sharedInstance.onShowChange() { show in
            self.setShowInfoFromShow(show)
            self.playingShow = show
            
            // set show duration
            if show != nil {
                let secs = show!.ends_at.timeIntervalSinceReferenceDate - show!.starts_at.timeIntervalSinceReferenceDate
                self.nowPlaying!.show_duration = Double(secs)
            }
        }
        
        //---
        
        AudioPlayer.sharedInstance.onStatusChange() { status in
            NSLog("view player status is %@",status.toString())
            
            switch status {
            case AudioPlayer.Statuses.New:
                true
            case AudioPlayer.Statuses.Playing:
                // set up for remote events
                self.becomeFirstResponder()
                UIApplication.sharedApplication().beginReceivingRemoteControlEvents()
                
                self.nowPlaying?.is_playing = true
                self._updateNowPlaying()
                
                true
            case AudioPlayer.Statuses.Stopped:
                // do something
                
                self.nowPlaying?.is_playing = false
                self._updateNowPlaying()
                
                true
            case AudioPlayer.Statuses.Paused:
                // do something
                
                self.nowPlaying?.is_playing = false
                self._updateNowPlaying()
                
                true
            default:
                // we don't care...
                true
            }
        }
        
        // -- load information for what's on now -- //
        
        Schedule.sharedInstance.at(NSDate()) { show in
            self.setShowInfoFromShow(show)
        }
    }
    
    //----------
    
    override func remoteControlReceivedWithEvent(event: UIEvent) {
        switch event.subtype {
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
        if ap.playing {
            NSLog("Pausing")
            ap.pause()
        } else {
            NSLog("Playing")
            ap.play()
        }
    }

    //----------

    func rewindTapped(sender:UIButton!) {
        let ap = AudioPlayer.sharedInstance

        if ap._currentShow != nil {
            ap.seekToDate(ap._currentShow!.soft_starts_at)
        }
    }

    //----------

    func sliderUpdated(sender:UISlider) {
        let ap = AudioPlayer.sharedInstance
        var fpercent = Float64(sender.value)
        ap.seekToPercent(fpercent)
    }

}

