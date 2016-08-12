//
//  SlackMessage.swift
//  PSlowMotion2
//
//  Created by Reng Tsai on 2016/8/11.
//  Copyright © 2016年 Reng Tsai. All rights reserved.
//

import Foundation
import MobileCoreServices


class SlackMessenger : NSObject{
    
    let SERVER_URL="https://l.facebook.com/l.php?u=https%3A%2F%2Fhooks.slack.com%2Fservices%2F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&h=IAQFCtsEa"
    
    var _session:Session!
    
    
    override init(){
        
        
    }
    func send(message_:String){
        
        
        print("send message...")
        
        let message_str="{\"text\":\"\(message_)\"}"
        let param = ["payload":message_str]  // build your dictionary however appropriate
        
        let boundary = "--Boundary\(NSUUID().UUIDString)"
        
        let url = NSURL(string: SERVER_URL)!
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        //request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        
        let bodyData = createBodyWithParameters(param, boundary: boundary)
        
        request.HTTPBody=bodyData
        request.HTTPShouldHandleCookies=false
        request.timeoutInterval=6000
        
        let queue:NSOperationQueue = NSOperationQueue()
        
        NSURLConnection.sendAsynchronousRequest(request, queue: queue, completionHandler:
            {(response: NSURLResponse?,data: NSData?,error: NSError?) -> Void in
                do{
                    print(NSString.init(data: data!, encoding:NSUTF8StringEncoding))
                    if let jsonResult = try NSJSONSerialization.JSONObjectWithData(data!, options: []) as? NSDictionary{
                        print("ASynchronous\(jsonResult)")
                    }
                }catch let error as NSError{
                    print(error.localizedDescription)
                }
                
                
        })
        
        
        
    }
    
    private func createBodyWithParameters(parameters: [String: String]?, boundary: String) -> NSData {
        let body = NSMutableData()
        //var body=NSData()
        //var body_string="";
        
        if parameters != nil {
            for (key, value) in parameters! {
                body.appendString("\r\n--\(boundary)\r\n")
                body.appendString("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
                body.appendString("\(value)")
                
            }
            body.appendString("\r\n");
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
}