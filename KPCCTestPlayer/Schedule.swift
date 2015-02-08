//
//  Schedule.swift
//  KPCCTestPlayer
//
//  Created by Eric Richardson on 1/17/15.
//  Copyright (c) 2015 Eric Richardson. All rights reserved.
//

import Foundation
import Alamofire
import SwiftyJSON

public class Schedule {
    public class var sharedInstance: Schedule {
        struct Static {
            static let instance = Schedule()
        }
        return Static.instance
    }
    
    //----------
    
    public struct ScheduleInstance {
        var id:             Int
        var slug:           String?
        var title:          String
        var url:            String?
        var starts_at:      NSDate
        var ends_at:        NSDate
        var soft_starts_at: NSDate
    }
    
    //----------
    
    let SCHEDULE_ENDPOINT = "http://www.scpr.org/api/v3/schedule"
    
    var _fetched:[ScheduleInstance]
    let _dateF = NSDateFormatter()
    
    init() {
        _fetched = []
        self._dateF.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSXXXXX"
    }
    
    //----------
    
    public func at(ts:NSDate,handler:(ScheduleInstance? -> Void)) -> Void {
        Alamofire.request(.GET,SCHEDULE_ENDPOINT+"/at", parameters:["time":ts.timeIntervalSince1970])
            .response { (req,res,data,err) in
                let json = JSON(data:data! as NSData)
                NSLog("json is %@", json.rawString()!)
                
                if json["meta"]["status"]["code"].number == 200 && json["schedule_occurrence"] != nil {
                    let so = json["schedule_occurrence"]
                    let slug: String?           = so["program"]["slug"].string
                    let title: String           = so["title"].stringValue
                    let url: String?            = so["url"].string
                    let starts_at: String       = so["starts_at"].stringValue
                    let ends_at: String         = so["ends_at"].stringValue
                    let soft_starts_at: String  = so["soft_starts_at"].stringValue
                    
                    let show = ScheduleInstance(
                        id:             0,
                        slug:           slug,
                        title:          title,
                        url:            url,
                        starts_at:      self._dateF.dateFromString(starts_at)!,
                        ends_at:        self._dateF.dateFromString(ends_at)!,
                        soft_starts_at: self._dateF.dateFromString(soft_starts_at)!
                    )
                    
                    // stash this show in memory
                    self._fetched.append(show)
                    
                    handler(show)
                } else {
                    handler(nil)
                }
            }
    }
    
    //----------
    
    public func from(start:NSDate, end:NSDate, handler:([ScheduleInstance]? -> Void)) -> Void {
        
    }
}