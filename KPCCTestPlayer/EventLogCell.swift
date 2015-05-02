//
//  EventLogCell.swift
//  KPCCTestPlayer
//
//  Created by Eric Richardson on 5/2/15.
//  Copyright (c) 2015 Eric Richardson. All rights reserved.
//

import UIKit

class EventLogCell : UITableViewCell {
    @IBOutlet weak var timestamp: UILabel!
    @IBOutlet weak var message: UILabel!
    
    let dateFormat = NSDateFormatter()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.dateFormat.dateFormat = "h:mm:ssa"
    }
    
    func setEvent(evt:AudioPlayer.Event) {
        self.timestamp.text = self.dateFormat.stringFromDate(evt.time)
        self.message.text = evt.message
    }
}