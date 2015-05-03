//
//  AccessLogViewController.swift
//  KPCCTestPlayer
//
//  Created by Eric Richardson on 2/21/15.
//  Copyright (c) 2015 Eric Richardson. All rights reserved.
//

import UIKit

class AccessLogViewController: UIViewController {
    @IBOutlet weak var logView: UITextView!
    
    var eventCount:UInt8 = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self._updateLog()
        
        AudioPlayer.sharedInstance.oAccessLog.addObserver() { log in
            self._updateLog()
            //self.tabBarItem.badgeValue = "\(self.eventCount++)"
            //NSLog("set accessLog badgeValue to \(self.tabBarItem.badgeValue)")
        }
        
//        AudioPlayer.sharedInstance.onStatusChange() { status in
//            switch status {
//            case .Playing:
//                // reset counter each time we start playing
//                self.eventCount = 0
//                self.tabBarItem.badgeValue = nil
//            default:
//                true
//            }
//        }
    }
    
    private func _updateLog() {
        let log = AudioPlayer.sharedInstance.getAccessLog()
        
        if log != nil {
            self.logView.text = NSString(data: log!.extendedLogData(), encoding: log!.extendedLogDataStringEncoding) as! String
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
