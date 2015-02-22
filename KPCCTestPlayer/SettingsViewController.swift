//
//  SettingsViewController.swift
//  KPCCTestPlayer
//
//  Created by Eric Richardson on 2/21/15.
//  Copyright (c) 2015 Eric Richardson. All rights reserved.
//

import UIKit

class SettingsViewController: UITableViewController {
    @IBOutlet weak var modeToggle: UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // make sure mode toggle matches AudioPlayer setting
        let current_mode = AudioPlayer.sharedInstance.getMode()
        
        if current_mode == .Production {
            self.modeToggle.on = true
        } else {
            self.modeToggle.on = false
        }
        
        // set a listener on the switch
        self.modeToggle.addTarget(self, action: "modeToggled:", forControlEvents: UIControlEvents.ValueChanged)
    }
    
    //----------
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //----------
    
    func modeToggled(sender:UISwitch!) {
        if self.modeToggle.on {
            NSLog("Setting audio mode to Production")
            AudioPlayer.sharedInstance.setMode(.Production)
        } else {
            NSLog("Setting audio mode to Testing")
            AudioPlayer.sharedInstance.setMode(.Testing)
        }
    }
}
