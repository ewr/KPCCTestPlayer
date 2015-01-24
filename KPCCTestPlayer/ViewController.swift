//
//  ViewController.swift
//  KPCCTestPlayer
//
//  Created by Eric Richardson on 1/6/15.
//  Copyright (c) 2015 Eric Richardson. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    @IBOutlet weak var timeDisplay: UILabel!
    @IBOutlet weak var playPauseButton: UIButton!
    @IBOutlet weak var progressSlider: UISlider!
    @IBOutlet weak var scheduleTable: UITableView!
    @IBOutlet weak var showLabel: UILabel!
    @IBOutlet weak var showTimes: UILabel!
    @IBOutlet weak var rewindButton: UIButton!
    
    var currentShow:Schedule.ScheduleInstance?
    
    let _timeF = NSDateFormatter()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

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
        }

        //---

        AudioPlayer.sharedInstance.onShowChange() { show in
            self.setShowInfoFromShow(show)
        }
        
        //---
        
        AudioPlayer.sharedInstance.onStatusChange() { status in
            NSLog("view player status is %@",status.toString())
            
            switch status {
            case AudioPlayer.Statuses.New:
                true
            case AudioPlayer.Statuses.Playing:
                // do something
                true
            case AudioPlayer.Statuses.Stopped:
                // do something
                true
            case AudioPlayer.Statuses.Paused:
                // do something
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

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    //----------
    
    func setShowInfoFromShow(show:Schedule.ScheduleInstance?) -> Void {
        if show != nil {
            self.showLabel.text = show!.title
            self.showTimes.text =
                self._timeF.stringFromDate(show!.starts_at) + " - " + self._timeF.stringFromDate(show!.ends_at)
            
        } else {
            self.showLabel.text = "????"
            self.showTimes.text = ""
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

