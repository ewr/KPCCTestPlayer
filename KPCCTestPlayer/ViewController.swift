//
//  ViewController.swift
//  KPCCTestPlayer
//
//  Created by Eric Richardson on 1/6/15.
//  Copyright (c) 2015 Eric Richardson. All rights reserved.
//

import UIKit
import MediaPlayer

class ViewController: UIViewController, UIPageViewControllerDataSource {
    @IBOutlet weak var timeDisplay: UILabel!
    @IBOutlet weak var playPauseButton: UIButton!
    @IBOutlet weak var liveButton: UIButton!
    
    var pageViewController:UIPageViewController!
    
//    var currentShow:Schedule.ScheduleInstance?
//    var playingShow:Schedule.ScheduleInstance?
    
    struct NowPlayingInfo {
        var title:String                = ""
        var is_playing:Bool             = false
        var show_duration:Double        = 0.0
        var current_duration:Double     = 0.0
        var current_time:String?        = nil
    }
    
    let _timeF = NSDateFormatter()
    
    var nowPlaying:NowPlayingInfo?
    
    struct ShowInBuffer {
        var show:Schedule.ScheduleInstance
        var view:ShowViewController?
    }
    
    var showsInBuffer:[ShowInBuffer?] = []
    var currentShow:ShowInBuffer?
    
    var _lastM:String?

    override func viewDidLoad() {
        super.viewDidLoad()

        // create our pageview 
        self.pageViewController = self.storyboard?.instantiateViewControllerWithIdentifier("PageViewController") as UIPageViewController
        self.pageViewController.dataSource = self
        
        self.nowPlaying = NowPlayingInfo()
        
        self.playPauseButton.addTarget(self, action: "playPauseTapped:", forControlEvents: UIControlEvents.TouchUpInside)
        self.liveButton.addTarget(self, action: "liveTapped:", forControlEvents: UIControlEvents.TouchUpInside)

        var formatter = NSDateFormatter()
        formatter.dateFormat = "YYYY-MM-DD hh:mm:ss"

        self._timeF.dateFormat = "h:mma"

        //---

        AudioPlayer.sharedInstance.observeTime() { (status:AudioPlayer.StreamDates) -> Void in
            // set current time display
            self.timeDisplay.text = formatter.stringFromDate(status.curDate)

            if status.minDate != nil {
                // set slider
                var duration: Double = status.maxDate!.timeIntervalSince1970 - status.minDate!.timeIntervalSince1970
                var position: Double = status.curDate.timeIntervalSince1970 - status.minDate!.timeIntervalSince1970

                var percent = position / duration

                self.currentShow!.view!.progressSlider.value = Float(percent)
            }
            
            let curM = self._timeF.stringFromDate(status.curDate)
            
            if (self._lastM == nil || curM != self._lastM) {
                if (self.currentShow != nil) {
                    let title = self.currentShow!.show.title + " (" + curM + ")"
                    self.nowPlaying!.title = title
                    self.nowPlaying!.current_duration = Double(status.curDate.timeIntervalSinceReferenceDate - self.currentShow!.show.starts_at.timeIntervalSinceReferenceDate)
                    
                    self._updateNowPlaying()
                    self._lastM = curM
                }
            }
        }

        // -- set show change observer -- #
        
        // AudioPlayer will tell us when the playhead crosses into a new show

        AudioPlayer.sharedInstance.onShowChange() { show in
//            self.setShowInfoFromShow(show)
//            self.playingShow = show
            
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
            default:
                // we don't care?
                true
            }
        }
        
        // -- set play/pause button state -- //
        
        // this could easily be done in the observer above, but setting our own 
        // allows for less code duplication in play/pause functionality
        
        AudioPlayer.sharedInstance.onStatusChange() { status in
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
        
        // -- load information for what's on now -- //
        
        let now = NSDate()
        let start_of_buffer = now.dateByAddingTimeInterval(-1 * Double(AudioPlayer.sharedInstance.NORMAL_REWIND))
        
        Schedule.sharedInstance.from(start_of_buffer, end: now) { shows in
            if shows != nil {
                // curent show will be the last one in the list
                //self.setShowInfoFromShow(shows!.last)

                for s in shows! {
                    self.showsInBuffer.append(ShowInBuffer(show:s, view:nil))
                }
                
                self.currentShow = self.showsInBuffer.last?

                self._setUpShowPages()
            }
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
   
//    func setShowInfoFromShow(show:Schedule.ScheduleInstance?) -> Void {
//        if show != nil {
//            self.showLabel.text = show!.title
//            self.showTimes.text =
//                self._timeF.stringFromDate(show!.starts_at) + " - " + self._timeF.stringFromDate(show!.ends_at)
//            
//            self.nowPlaying?.title = show!.title
//            self._updateNowPlaying()
//            
//        } else {
//            self.showLabel.text = "????"
//            self.showTimes.text = ""
//            
//            self.nowPlaying?.title = ""
//            self._updateNowPlaying()
//        }
//    }
    
    //----------

    func playPauseTapped(sender:UIButton!) {
        let ap = AudioPlayer.sharedInstance
        
        switch ap.status {
        case .Playing:
            ap.pause()
        case .Paused, .New:
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
            ap.seekToDate(self.currentShow!.show.soft_starts_at)
        }
    }

    //----------

    func sliderUpdated(sender:UISlider) {
        let ap = AudioPlayer.sharedInstance
        var fpercent = Float64(sender.value)
        ap.seekToPercent(fpercent)
    }
    
    //----------
    
    private func _setUpShowPages() {
        // build our current page
        self.currentShow!.view = self.storyboard?.instantiateViewControllerWithIdentifier("ShowContentController") as? ShowViewController
        self.currentShow!.view!.show = self.currentShow!.show
    }
    
    //----------
    
    func pageViewController(pageViewController: UIPageViewController, viewControllerAfterViewController viewController: UIViewController) -> UIViewController? {
        
        return nil
    }
    
    //----------
    
    func pageViewController(pageViewController: UIPageViewController, viewControllerBeforeViewController viewController: UIViewController) -> UIViewController? {
    
        return nil
    }
    
    //----------
    
    func presentationCountForPageViewController(pageViewController: UIPageViewController) -> Int {
        return self.showsInBuffer.count
    }
    
    //----------
    
    func presentationIndexForPageViewController(pageViewController: UIPageViewController) -> Int {
        return self.showsInBuffer.count - 1
    }

}

