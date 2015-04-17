//
//  AudioPlayerAssetLoader.swift
//  KPCCTestPlayer
//
//  Created by Eric Richardson on 3/4/15.
//  Copyright (c) 2015 Eric Richardson. All rights reserved.
//

import Foundation
import AVFoundation
import Alamofire

class AudioPlayerAssetLoader: NSObject, AVAssetResourceLoaderDelegate {
    let _manager:Alamofire.Manager
    
    let queue = dispatch_queue_create("is.ewr.KPCCTestPlayer.audioAssets", DISPATCH_QUEUE_CONCURRENT)
    
    struct LoadRequest {
        var loader:     AVAssetResourceLoadingRequest
        var request:    Alamofire.Request?
        var start_time: NSDate
    }
    
    var _loaders:[LoadRequest] = []
    
    override init() {
        var headers = Alamofire.Manager.sharedInstance.session.configuration.HTTPAdditionalHeaders ?? [:]
        headers["User-Agent"] = "KPCC-EWR 0.1"
        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
        config.HTTPAdditionalHeaders = headers
        
        self._manager = Alamofire.Manager(configuration:config)
    }
    
    func resourceLoader(resourceLoader: AVAssetResourceLoader!, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest!) -> Bool {
        
        // we want to convert the fake proto to http, then do the load
        let url = NSURLComponents(URL: loadingRequest.request.URL!, resolvingAgainstBaseURL: false)
        
        if url != nil {
            url!.scheme = "http"
            
            if (url!.path!.rangeOfString(".aac") != nil) {
                // we're not allowed to fetch segment data ourself. we have to just return a 
                // redirect to the actual http URL
                NSLog("Redirecting request for \(url!.URL!)")
                loadingRequest.redirect = NSURLRequest(URL: url!.URL!)
                let response = NSHTTPURLResponse(URL: url!.URL!, statusCode:302, HTTPVersion:nil, headerFields:nil)
                loadingRequest.response = response
                loadingRequest.finishLoading()
                return false
                
            } else {
            
                var load_request = LoadRequest(loader: loadingRequest, request: nil, start_time: NSDate())
                self._loaders.append(load_request)
                
                load_request.request = self._manager.request(.GET, url!.string!).response { (req,res,data,err) in
                    dispatch_async(dispatch_get_main_queue()) {
                        NSLog("request finished: %@",url!.string!)
                        //loadingRequest.response = res
                        
                        // set the data
                        loadingRequest.dataRequest.respondWithData(data as! NSData)
                        
                        NSLog("Added data. Offset is now \(loadingRequest.dataRequest.currentOffset)")
                        
                        // FIXME: I'm not confident any of this contentInformationRequest makes a difference
                        if loadingRequest.contentInformationRequest != nil {
                            // contentType is a little funky...
                            if (url!.path!.rangeOfString(".aac") != nil) {
                                loadingRequest.contentInformationRequest.contentType = "public.aac-audio"
                            } else if (url!.path!.rangeOfString(".m3u8") != nil) {
                                loadingRequest.contentInformationRequest.contentType = "public.m3u-playlist"
                            }
                            
                            // data length
                            loadingRequest.contentInformationRequest.contentLength = data!.length!
                            NSLog("contentLength is \(loadingRequest.contentInformationRequest.contentLength)")
                            
                            loadingRequest.contentInformationRequest.byteRangeAccessSupported = false
                        }
                        
                        // we're done
                        loadingRequest.finishLoading()
                        
                        // how long did it take?
                        let end_date = NSDate()
                        let duration = end_date.timeIntervalSinceReferenceDate - load_request.start_time.timeIntervalSinceReferenceDate
                        NSLog("request took \(duration)")
                        
                        // clean up...
                        for (idx,l) in enumerate(self._loaders) {
                            if l.loader == load_request.loader {
                                self._loaders.removeAtIndex(idx)
                                break
                            }
                        }
                        
                        NSLog("AssetLoader has \(self._loaders.count) pending requests.")
                    }

                }
                
                //debugPrintln(request)
                
                return true
            }
        } else {
            NSLog("failed to figure out request for %@", loadingRequest.request.URL!)
            return false
        }
    }
}