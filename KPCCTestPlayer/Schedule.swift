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
    public static let sharedInstance = Schedule()
    
    //----------
    
    public struct ScheduleInstance {
        public var id:             Int
        public var slug:           String?
        public var title:          String
        public var url:            String?
        public var starts_at:      NSDate
        public var ends_at:        NSDate
        public var soft_starts_at: NSDate
        
        func percentToDate(percent:Float64) -> NSDate? {
            let duration:Double = ends_at.timeIntervalSince1970 - starts_at.timeIntervalSince1970
            let seconds:Double = duration * percent
            return starts_at.dateByAddingTimeInterval(seconds)
        }
    }
    
    //----------
    
    public typealias ScheduleInstanceHandler   = (ScheduleInstance? -> Void)
    public typealias ScheduleInstancesHandler  = ([ScheduleInstance]? -> Void)
    
    //----------
    
    let SCHEDULE_ENDPOINT = "http://www.scpr.org/api/v3/schedule"
    
    var _fetched:[ScheduleInstance]
    let _dateF = NSDateFormatter()
    
    init() {
        _fetched = []
        self._dateF.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSXXXXX"
    }
    
    //----------
    
    private func _createScheduleInstance(so:JSON) -> ScheduleInstance {
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

        return show
    }
    
    //----------
    
    public func at(ts:NSDate,handler:ScheduleInstanceHandler) -> Void {
        Alamofire.request(.GET,SCHEDULE_ENDPOINT+"/at", parameters:["time":ts.timeIntervalSince1970])
            .response { (req,res,data,err) in
                guard err == nil else {
                    print("err is \(err)")
                    handler(nil)
                    return
                }
                
                let json = JSON(data:data!)
                NSLog("json is %@", json.rawString()!)
                
                if json["meta"]["status"]["code"].number == 200 && json["schedule_occurrence"] != nil {
                    let show = self._createScheduleInstance(json["schedule_occurrence"])
                    
                    // stash this show in memory
                    self._fetched.append(show)
                    
                    handler(show)
                } else {
                    handler(nil)
                }
            }
    }
    
    //----------
    
    public func from(start:NSDate, end:NSDate, handler:ScheduleInstancesHandler) -> Void {
        // to get a date range, we need to compute the duration between start and end, since 
        // the KPCC api takes start and duration
        let start_secs = start.timeIntervalSince1970
        let duration = end.timeIntervalSince1970 - start_secs
        
        Alamofire.request(.GET,SCHEDULE_ENDPOINT, parameters:["start":start_secs,"duration":duration])
            .response { (req,res,data,err) in
                let json = JSON(data:data!)
                NSLog("json is %@", json.rawString()!)
                
                var shows: [ScheduleInstance] = []
                if json["meta"]["status"]["code"].number == 200 && json["schedule_occurrences"] != nil {
                    for so in json["schedule_occurrences"].array! {
                        let show = self._createScheduleInstance(so)
                        shows.append(show)
                    }
                    
                    handler(shows)
                    
                } else {
                    NSLog("Failed to fetch schedule block.")
                    handler(nil)
                }
        }
    }
}