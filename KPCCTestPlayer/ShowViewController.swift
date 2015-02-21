//
//  ShowViewController.swift
//  KPCCTestPlayer
//
//  Created by Eric Richardson on 2/15/15.
//  Copyright (c) 2015 Eric Richardson. All rights reserved.
//

import UIKit

class ShowViewController: UIViewController {
    
    var show:Schedule.ScheduleInstance?

    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var showLabel: UILabel!
    @IBOutlet weak var airtimeLabel: UILabel!
    @IBOutlet weak var progressSlider: UISlider!
    
    @IBOutlet weak var playButton: UIButton!
    
    let _timeF = NSDateFormatter()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self._timeF.dateFormat = "h:mma"

        self.showLabel.text = self.show!.title
        self.airtimeLabel.text = self._timeF.stringFromDate(self.show!.starts_at) + " - " + self._timeF.stringFromDate(self.show!.ends_at)
        
        self.progressSlider.hidden = true
        
        //        self.progressSlider.addTarget(self, action: "sliderUpdated:", forControlEvents: UIControlEvents.ValueChanged)
        //        self.rewindButton.addTarget(self, action: "rewindTapped:", forControlEvents: UIControlEvents.TouchUpInside)

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
