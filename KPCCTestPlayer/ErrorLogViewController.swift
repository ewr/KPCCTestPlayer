//
//  ErrorLogViewController.swift
//  KPCCTestPlayer
//
//  Created by Eric Richardson on 2/21/15.
//  Copyright (c) 2015 Eric Richardson. All rights reserved.
//

import UIKit

class ErrorLogViewController: UIViewController {

    @IBOutlet weak var logView: UITextView!
    
    var eventCount:UInt8 = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // render current error log into the text view
        self._updateLog()
        
        AudioPlayer.sharedInstance.onErrorLog() { log in
            self._updateLog()
            
            //self.tabBarItem.badgeValue = "\(self.eventCount++)"
        }
        
//        AudioPlayer.sharedInstance.onStatusChange() { status in
//            switch status {
//            case .Playing:
//                // reset counter
//                self.eventCount = 0
//                self.tabBarItem.badgeValue = nil
//            default:
//                true
//            }
//        }
    }
    
    private func _updateLog() {
        let log = AudioPlayer.sharedInstance.getErrorLog()
        
        if log != nil {
            self.logView.text = NSString(data: log!.extendedLogData(), encoding: log!.extendedLogDataStringEncoding)
        }
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
