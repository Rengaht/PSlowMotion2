//
//  ViewController.swift
//  PSlowMotion2
//
//  Created by Reng Tsai on 2016/7/27.
//  Copyright © 2016年 Reng Tsai. All rights reserved.
//

import UIKit
import AVFoundation
import NetworkExtension

class ViewController: UIViewController,F53OSCPacketDestination,UIGestureRecognizerDelegate,NSXMLParserDelegate{
    
    
    let MAINUI_OSC_IP="192.168.1.140"
    let MAINUI_OSC_PORT=UInt16(12888)
    
    let QRCODE_OSC_IP="192.168.1.140"
    let QRCODE_OSC_PORT=UInt16(12999)
    
    let SERVER_URL="http://mmlab.bremennetwork.tw/extra2016/"
    let FTP_URL="ftp://mmlab.bremennetwork.tw"
    let UPLOAD_URL="upload/action.php"
    
    var startButton, composeButton: UIButton!
    var messageText:UILabel!
    var zoomInButton,zoomOutButton:UIButton!
    
    var isRecording = false
    let cameraEngine = SlowCameraEngine()
    
    var timer:NSTimer!
    let RECORD_TIME=2.0;
    
    let videoComposer = VideoComposer()
    let videoUploader = VideoUploader()
    let stickerComposer=StickerFrameComposer()
    let overlayCompose=OverlayComposer()
    
    
    //OSC
    var video_id:String!
    //var osc_client:F53OSCClient!
    var osc_server:F53OSCServer!
    
    // osc send
    var osc_client:F53OSCClient!
    var osc_qrcode_client:F53OSCClient!
    
    var isProcessing=false
    var record_path:String!
    var sticker_path:String!
    var overlay_path:String!
    
    var beginTime:CFAbsoluteTime!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.beginTime=CFAbsoluteTimeGetCurrent()
        
        // Do any additional setup after loading the view.
        cameraEngine.startup()
        let videoLayer = AVCaptureVideoPreviewLayer(session: cameraEngine.captureSession)
        videoLayer.frame = view.bounds
        videoLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        videoLayer.connection.videoOrientation=AVCaptureVideoOrientation.LandscapeRight
        
        view.layer.addSublayer(videoLayer)
        
        loadPosXML()
        setupUI()
        
        self.cameraEngine.events.listenTo("record_finish",action: {(info: Any?) in
            print("record finish...")
            self.record_path=info as! String
            //self.overlayCompose.composeOverlayVideo(self.record_path)
            self.changeButtonColor(self.startButton, color: UIColor.redColor())
            
        })
        self.overlayCompose.events.listenTo("overlay_finish",action: {(info: Any?) in
            
            let process_time=CFAbsoluteTimeGetCurrent()
            let t_=NSString(format: "%.2f",(process_time-self.beginTime))
            print("overlay finish... after \(t_)")
            
            self.overlay_path=info as! String
            
            self.messageText.text?.appendContentsOf("\noverlay finish \(t_)")
            self.videoComposer.combineVideo(self.overlay_path,sticker_path:self.sticker_path)
            
        })
//        self.videoComposer.events.listenTo("ending_finish",action: {(info: Any?) in
//            print("ending finish...")
//            if(self.video_id==nil){
//                self.video_id="test"
//            }
//            self.videoComposer.combineVideo(self.record_path,sticker_path: info as! String)
//        })
        self.stickerComposer.events.listenTo("sticker_finish",action: {(info: Any?) in
            
            let process_time=CFAbsoluteTimeGetCurrent()
            let t_=NSString(format: "%.2f",(process_time-self.beginTime))
            print("sticker finish... after \(t_)")
            self.messageText.text?.appendContentsOf("\nsticker finish \(t_)")
            
            if(self.video_id==nil){
                self.video_id="test"
            }
            self.sticker_path=info as! String
            self.overlayCompose.composeOverlayVideo(self.record_path)
            
            
        })
        
        self.videoComposer.events.listenTo("compose_finish",action: {(info: Any?) in
            
            let process_time=CFAbsoluteTimeGetCurrent()
            let t_=NSString(format: "%.2f",(process_time-self.beginTime))
            print("compose finish... after \(t_)")
            self.messageText.text?.appendContentsOf("\ncompose finish \(t_)")
            
            
            if(self.video_id==nil){
                self.video_id="test"
            }
            self.videoUploader.uploadVideo(info as! String, vid: self.video_id, server_url: String(self.SERVER_URL+self.UPLOAD_URL))
            //self.videoUploader.uploadVideoFTP(info as! String, vid: self.video_id, server_url: self.FTP_URL)
        })
        self.videoUploader.events.listenTo("upload_finish",action: {(info: Any?) in
            
            let process_time=CFAbsoluteTimeGetCurrent()
            let t_=NSString(format: "%.2f",(process_time-self.beginTime))
            print("upload finish...\(t_)")
            self.messageText.text?.appendContentsOf("\nupload finish \(t_)")
           
        
            if((info) != nil){
                self.sendResultMessage(info as! String)
                self.isProcessing=false
            }
            self.changeButtonColor(self.composeButton, color: UIColor.grayColor())
        })
        self.videoUploader.events.listenTo("upload_fail",action: {(info: Any?) in
            
            let process_time=CFAbsoluteTimeGetCurrent()
            let t_=NSString(format: "%.2f",(process_time-self.beginTime))
            print("upload fail...\(t_)")
            self.messageText.text?.appendContentsOf("\nupload fail \(t_)")
            
            
            self.changeButtonColor(self.composeButton, color: UIColor.grayColor())
        })
        
        // osc receive
        osc_server=F53OSCServer.init()
        osc_server.port=12777
        osc_server.delegate=self
        if osc_server.startListening() {
            print("osc start listening...\(osc_server.port)")
        }else{
            print("osc start fail...\(osc_server.port)")
        }
        
        osc_client=F53OSCClient.init()
        osc_client.host=self.MAINUI_OSC_IP
        osc_client.port=self.MAINUI_OSC_PORT
        
        osc_qrcode_client=F53OSCClient.init()
        osc_qrcode_client.host=self.QRCODE_OSC_IP
        osc_qrcode_client.port=self.QRCODE_OSC_PORT
        
        isProcessing=false
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        UIApplication.sharedApplication().idleTimerDisabled = true
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        UIApplication.sharedApplication().idleTimerDisabled = false
    }
    
    func setupUI(){
        
        let screenSize: CGRect = UIScreen.mainScreen().bounds
        
        
        startButton = UIButton(frame: CGRectMake(screenSize.width-100, 20, 60 ,50))
        startButton.backgroundColor = UIColor.redColor()
        startButton.layer.masksToBounds = true
        startButton.setTitle("start", forState: .Normal)
        startButton.layer.cornerRadius = 0.0
        startButton.addTarget(self, action: #selector(onClickStartButton(_:)), forControlEvents: .TouchUpInside)
        
        composeButton = UIButton(frame: CGRectMake(screenSize.width-200, 20, 80, 50))
        composeButton.backgroundColor = UIColor.grayColor()
        composeButton.layer.masksToBounds = true
        composeButton.setTitle("process", forState: .Normal)
        composeButton.layer.cornerRadius = 0.0
        composeButton.addTarget(self, action: #selector(onClickComposeButton(_:)), forControlEvents: .TouchUpInside)
        
        
        
        //messageText=UITextView(frame: CGRectMake(20, 20, view.bounds.width, view.bounds.height-130))
        messageText=UILabel(frame: CGRectMake(screenSize.width/2,100,screenSize.width/2-80,200))
        messageText.lineBreakMode = .ByWordWrapping
        messageText.numberOfLines=0
        messageText.textColor=UIColor.redColor()
        messageText.text=getWiFiAddress()
        
        
        zoomInButton=UIButton(frame: CGRectMake(screenSize.width-80,100,50,50))
        zoomInButton.backgroundColor=UIColor.blueColor()
        zoomInButton.setTitle("+", forState: .Normal)
        zoomInButton.layer.cornerRadius=25
        zoomInButton.addTarget(self, action: #selector(onZoomInButton(_:)), forControlEvents: .TouchUpInside)
        
        zoomOutButton=UIButton(frame: CGRectMake(screenSize.width-80,160,50,50))
        zoomOutButton.backgroundColor=UIColor.blueColor()
        zoomOutButton.setTitle("-", forState: .Normal)
        zoomOutButton.layer.cornerRadius=25
        zoomOutButton.addTarget(self, action: #selector(onZoomOutButton(_:)), forControlEvents: .TouchUpInside)

        
        
        view.addSubview(startButton)
        view.addSubview(composeButton)
        view.addSubview(messageText)
        view.addSubview(zoomInButton)
        view.addSubview(zoomOutButton)
        
        //view.addSubview(messageText)
        
        //view.addSubview(stopButton);
        let shortTap = UITapGestureRecognizer(target: self, action: #selector(onTapScreen(_:)))
        shortTap.delegate=self
        shortTap.numberOfTapsRequired=1;
        shortTap.numberOfTouchesRequired=1;
        view.addGestureRecognizer(shortTap)
        
    }
    
    func onTapScreen(sender: UITapGestureRecognizer){
        
        let thisFocusPoint = sender.locationInView(view)
        let screenRect = UIScreen.mainScreen().bounds;
        let screenWidth = screenRect.size.width;
        let screenHeight = screenRect.size.height;
        
        let focus_x = thisFocusPoint.x/screenWidth;
        let focus_y = thisFocusPoint.y/screenHeight;

        
        cameraEngine.setFocusAt(focus_x,fy: focus_y)
        
    }
    func onClickStartButton(sender: UIButton){
        startRecord()
    }
    func startRecord(){
        if !cameraEngine.isCapturing {
            cameraEngine.start()
            changeButtonColor(startButton, color: UIColor.grayColor())
            //changeButtonColor(stopButton, color: UIColor.redColor())
            
//            self.timer=NSTimer.scheduledTimerWithTimeInterval(self.RECORD_TIME, target: self, selector: #selector(ViewController.stopRecord), userInfo: nil, repeats: false)
        }
    }
    
    func onClickComposeButton(sender: UIButton){
        if(!isProcessing){
            changeButtonColor(composeButton, color: UIColor.redColor())
            
            var now = NSDate()
            var formatter = NSDateFormatter()
            //formatter.dateFormat = "yyyyMMddHHmmss"
            //self.video_id="test\(formatter.stringFromDate(now))"
            
            startCompose("test2")
        }
    }
    func startCompose(vid_:String){
                
            
        self.messageText.text?.appendContentsOf("\nstart compose...\(vid_)")
        
        
        let img_=downloadImage("\(self.SERVER_URL)\(vid_).png")
        //self.videoComposer.composeEndingPart(img_)
        
        self.beginTime=CFAbsoluteTimeGetCurrent()
        
        self.stickerComposer.composeEndingPart(img_)
        
    }
    
    func stopRecord(){
        if cameraEngine.isCapturing {
            cameraEngine.stop()
            changeButtonColor(startButton, color: UIColor.redColor())
            
        }
    }
    
    func changeButtonColor(target: UIButton, color: UIColor){
        target.backgroundColor = color
    }
    
    func onZoomInButton(sender:UIButton){
        cameraEngine.zoomIn()
    }
    func onZoomOutButton(sender:UIButton){
        cameraEngine.zoomOut()
    }
    
    //@add for F53OSC ############
    func takeMessage(message: F53OSCMessage!) {
        
        print("Received '\(message)'")
        if(message.addressPattern=="/video_start"){
            self.video_id=message.arguments[0] as! String
            
            self.messageText.text=self.getWiFiAddress()
            self.messageText.text?.appendContentsOf("\nStart Record \(self.video_id)")
            startRecord()
        
        }else if(message.addressPattern=="/compose_start"){
            if(message.arguments[0] as! String != video_id){
                print("Incompatible ID: \(message.arguments[0] as! String) -> \(video_id)");
            }
            startCompose("st_\(video_id)")
        }
        
//        let addressPattern = message.addressPattern
//        let arguments = message.arguments
    }
    
    func sendResultMessage(message:String){
        
        let message = F53OSCMessage(addressPattern: "/video_finish", arguments: [message])
        osc_qrcode_client.sendPacket(message)
        
        //osc_client.sendPacket(message)
        
    }
    
    func downloadImage(url_:String) -> UIImage{
        let data = NSData(contentsOfURL: NSURL(string:url_)!) //make sure your image in this url does exist, otherwise unwrap in a if let check
        return UIImage(data: data!)!
    }
    
    
    func loadPosXML(){
        var path=NSBundle.mainBundle().pathForResource("_pos", ofType: "xml")
        var xml_=NSXMLParser.init(contentsOfURL: NSURL.init(fileURLWithPath: path!))
        xml_!.delegate=self
        xml_!.parse()
        
        stickerComposer.loadEndingFrames()
        overlayCompose.loadOverlayFrames()
    }
    func parserDidStartDocument(parser: NSXMLParser) {
        print("Start parsing XML!");
    }
    func parser(parser: NSXMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        
        if(elementName=="FRAME"){
            let posx=attributeDict["X"] as! NSString
            let posy=attributeDict["Y"] as! NSString
            stickerComposer.arr_pos_x.addObject(623+posx.doubleValue*0.6667-251)
            stickerComposer.arr_pos_y.addObject((336+posy.doubleValue*0.6667-502))
            
//            videoComposer.arr_pos_x.addObject(623+posx.doubleValue*0.6667)
//            videoComposer.arr_pos_y.addObject(720-(336+posy.doubleValue*0.6667))
            
        }
    }
    func parser(parser: NSXMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        //print("end element: \(elementName)")
    }
    func parserDidEndDocument(parser: NSXMLParser){
        print("End parsing XML!");
    }
    
    
    func getWiFiAddress() -> String? {
        var address:String=""
        
        // Get list of all interfaces on the local machine:
        var ifaddr : UnsafeMutablePointer<ifaddrs> = nil
        if getifaddrs(&ifaddr) == 0 {
            
            // For each interface ...
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr.memory.ifa_next }
                
                let interface = ptr.memory
                
                // Check for IPv4 or IPv6 interface:
                let addrFamily = interface.ifa_addr.memory.sa_family
                if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                    
                    // Check interface name:
                    if let name = String.fromCString(interface.ifa_name) where name == "en0" {
                        
                        // Convert interface address to a human readable string:
                        var addr = interface.ifa_addr.memory
                        var hostname = [CChar](count: Int(NI_MAXHOST), repeatedValue: 0)
                        getnameinfo(&addr, socklen_t(interface.ifa_addr.memory.sa_len),
                                    &hostname, socklen_t(hostname.count),
                                    nil, socklen_t(0), NI_NUMERICHOST)
                        address = String.fromCString(hostname)!
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        
        return address
    }
    
}

