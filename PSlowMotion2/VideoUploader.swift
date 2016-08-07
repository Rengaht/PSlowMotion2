//
//  VideoUploader.swift
//  PSlowMotion2
//
//  Created by Reng Tsai on 2016/7/27.
//  Copyright © 2016年 Reng Tsai. All rights reserved.
//

import Foundation
import MobileCoreServices
import Alamofire


extension NSMutableData {
    
    func appendString(string: String) {
        let data = string.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)
        appendData(data!)
    }
}

class VideoUploader : NSObject{
    
    let events=EventManager()
    var waiting_id:NSMutableArray=[]
    
    override init(){
        
    }
    func uploadVideo(video_path:String, vid:String,server_url:String){
        
       // waiting_id.addObject(vid)
        
        print("upload video...")
        
        
        let param = ["action":"upload_video", "guid" : vid]  // build your dictionary however appropriate

        let boundary = "--Boundary\(NSUUID().UUIDString)"
        
        let url = NSURL(string: server_url)!
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        //request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        
        let bodyData = createBodyWithParameters(param, filePathKey: "file", paths: [video_path], boundary: boundary)
        print("upload size= \(bodyData.length/100000) MB");

        request.HTTPBody=bodyData
        request.HTTPShouldHandleCookies=false
        
        let queue:NSOperationQueue = NSOperationQueue()

        NSURLConnection.sendAsynchronousRequest(request, queue: queue, completionHandler:
            {(response: NSURLResponse?,data: NSData?,error: NSError?) -> Void in
                        do{
                            if let jsonResult = try NSJSONSerialization.JSONObjectWithData(data!, options: []) as? NSDictionary{
                                print("ASynchronous\(jsonResult)")
            
                                //if jsonResult["result"] as! String == "success" {
                                    self.events.trigger("upload_finish", information:jsonResult["guid"])
                                //}
                            }
                        }catch let error as NSError{
                            print(error.localizedDescription)
                        }
                        
                        
        })

        
        
    }
    
    private func createBodyWithParameters(parameters: [String: String]?, filePathKey: String?, paths: [String]?, boundary: String) -> NSData {
        let body = NSMutableData()
        //var body=NSData()
        //var body_string="";
        
        if parameters != nil {
            for (key, value) in parameters! {
                body.appendString("\r\n--\(boundary)\r\n")
                body.appendString("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
                body.appendString("\(value)")
                
            }
        }
        
        if paths != nil {
            for path in paths! {
                let url = NSURL(fileURLWithPath: path)
                let filename = url.lastPathComponent
                let data = NSData(contentsOfURL: url)!
                let mimetype = mimeTypeForPath(path)
                
                body.appendString("--\(boundary)\r\n")
                body.appendString("Content-Disposition: form-data; name=\"\(filePathKey!)\"; filename=\"\(filename!)\"\r\n")
                body.appendString("Content-Type: \(mimetype)\r\n\r\n")
                body.appendData(data)
                body.appendString("\r\n")
                
            }
        }
        
        body.appendString("--\(boundary)--\r\n")
        
        return body
    }
    
    private func mimeTypeForPath(path: String) -> String {
        let url = NSURL(fileURLWithPath: path)
        let pathExtension = url.pathExtension
        
        if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension! as NSString, nil)?.takeRetainedValue() {
            if let mimetype = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue() {
                return mimetype as String
            }
        }
        return "application/octet-stream";
    }
    
    func uploadVideoFTP(video_path:String, vid:String,server_url:String){
        print("Upload with FTP...");
        
        var config = SessionConfiguration()
        config.host = server_url
        config.username = "mmlabnetwork"
        config.password = "fAg5h@j"
        
        let _session=Session(configuration: config)
       
        let path = "/extra2016/\(vid).mp4"
        _session.upload(NSURL(fileURLWithPath: video_path), path: path) {
                (result, error) -> Void in
                print("Upload \(vid) file with result:\(result), error: \(error)")
            if(error==nil){
                self.events.trigger("upload_finish", information:vid)
            }
        }
        
    }
    
}
