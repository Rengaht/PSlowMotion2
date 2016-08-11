//
//  StickerFrameComposer.swift
//  PSlowMotion2
//
//  Created by Reng Tsai on 2016/8/7.
//  Copyright © 2016年 Reng Tsai. All rights reserved.
//
import Foundation
import AVFoundation
import AssetsLibrary
import UIKit


class StickerFrameComposer : NSObject{
    
    let events=EventManager()
    
    var arr_pos_x:NSMutableArray=[]
    var arr_pos_y:NSMutableArray=[]
    
    var arr_frame:NSMutableArray!
    var stickerWidth:Double!
    
    private var outputPath: String {
        get {
            let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
            let documentsDirectory = paths[0] as String
            let filePath : String = "\(documentsDirectory)/sticker.mp4"
            return filePath
        }
    }
    override init(){
        self.stickerWidth=502
    }
    
    func loadEndingFrames(){
        arr_frame=NSMutableArray.init(capacity:150)
        for i in 0...299{
            let name_=String.init(format:"%03d",i)
            let path_ = NSBundle.mainBundle().pathForResource("extra_part2\(name_)", ofType: "png",inDirectory: "end_seq")
            let data = NSData(contentsOfURL:NSURL(fileURLWithPath:path_!))
            arr_frame.addObject(UIImage(data:data!)!)
        }
        
    }
    
    func composeEndingPart(stickerImage:UIImage){
        
        writeImages(stickerImage,videoPath: self.outputPath)
    }
    
    func createOverlayImage(stickerImage:UIImage,backImage:UIImage,drawRect:CGRect,angle:Double,alpha:Double)->UIImage{
        
        if alpha==0 { return backImage }
        
//        //create alpha image
//        UIGraphicsBeginImageContextWithOptions(drawRect.size, false, 0.0)
//        let abitmap=UIGraphicsGetCurrentContext()
//        CGContextSetAlpha(abitmap, CGFloat(alpha))
//        
//            stickerImage.drawInRect(CGRectMake(0, 0, drawRect.width, drawRect.height))
//        
//        let alphaImage = UIGraphicsGetImageFromCurrentImageContext()
//        UIGraphicsEndImageContext()
        
        let ang=angle/180.0*M_PI
        
        let newSize = CGSizeMake(1280,720) // set this to what you need
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        let bitmap=UIGraphicsGetCurrentContext()
        
        backImage.drawInRect(CGRect(origin: CGPointZero, size: newSize))
        
        CGContextTranslateCTM(bitmap, drawRect.minX, drawRect.midY)
        CGContextTranslateCTM(bitmap, drawRect.size.width/2.0, drawRect.size.height/2.0)
        CGContextRotateCTM(bitmap, CGFloat(ang))
        
        stickerImage.drawInRect(CGRect(origin: CGPointMake(-drawRect.size.width/2.0, -drawRect.size.height/2.0), size:drawRect.size), blendMode: CGBlendMode.Normal, alpha: CGFloat(alpha))
           // .drawInRect(CGRect(origin: CGPointMake(-drawRect.size.width/2.0, -drawRect.size.height/2.0), size:drawRect.size))
        
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    func writeImages(stikerImage:UIImage, videoPath: String){
        
        let manager = NSFileManager()
        do{
            try manager.removeItemAtPath(videoPath)
        }catch{
            print("file doesn't exist or couldn't remove file at path")
        }
        
        let videoSize=CGSizeMake(1280, 720)
        let videoFPS=Int32(30)
        
        
        // Create AVAssetWriter to write video
        guard let assetWriter = createAssetWriter(outputPath, size: videoSize) else {
            print("Error converting images to video: AVAssetWriter not created")
            return
        }
        
        // If here, AVAssetWriter exists so create AVAssetWriterInputPixelBufferAdaptor
        let writerInput = assetWriter.inputs.filter{ $0.mediaType == AVMediaTypeVideo }.first!
        let sourceBufferAttributes : [String : AnyObject] = [
            kCVPixelBufferPixelFormatTypeKey as String : Int(kCVPixelFormatType_32ARGB),
            kCVPixelBufferWidthKey as String : videoSize.width,
            kCVPixelBufferHeightKey as String : videoSize.height,
            ]
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: sourceBufferAttributes)
        
        // Start writing session
        assetWriter.startWriting()
        assetWriter.startSessionAtSourceTime(kCMTimeZero)
        if (pixelBufferAdaptor.pixelBufferPool == nil) {
            print("Error converting images to video: pixelBufferPool nil after starting session")
            return
        }
        
        // -- Create queue for <requestMediaDataWhenReadyOnQueue>
        let mediaQueue = dispatch_queue_create("mediaInputQueue", nil)
        
        // -- Set video parameters
        let frameDuration = CMTimeMake(1, videoFPS)
        var frameCount = 0
        
        // -- Add images to video
        let numImages = arr_frame.count
        writerInput.requestMediaDataWhenReadyOnQueue(mediaQueue, usingBlock: { () -> Void in
            // Append unadded images to video but only while input ready
            while (writerInput.readyForMoreMediaData && frameCount < numImages) {
                let lastFrameTime = CMTimeMake(Int64(frameCount), videoFPS)
                let presentationTime = frameCount == 0 ? lastFrameTime : CMTimeAdd(lastFrameTime, frameDuration)
                
                var fr=0
                var ang_=0.0
                var a_=1.0
                
                if frameCount<99 {
                    fr=0
                    a_=0
                }else if frameCount>139 {
                    fr=40-1
                    if frameCount>222 {
                        a_=0
                    }else if frameCount>209 {
                        a_=1.0-(Double(frameCount)-209.0)/13.0
                    }
                    
                }else{
                    fr=frameCount-99
                    if fr>30 { ang_=20.0-20.0*(Double(fr)-30.0)/10.0 }
                    else if fr>20 { ang_=50.0*(Double(fr)-20.0)/10.0-30.0 }
                    else if fr>5 { ang_=0-30*(Double(fr)-5.0)/15.0 }
                    else { a_=Double(fr)/5.0 }
                }
                
                let rect=CGRectMake(CGFloat(Float(self.arr_pos_x[fr] as! NSNumber)),CGFloat(Float(self.arr_pos_y[fr] as! NSNumber)),CGFloat(self.stickerWidth),CGFloat(self.stickerWidth))
                
                let overImage=self.createOverlayImage(stikerImage, backImage: self.arr_frame[frameCount] as! UIImage,
                    drawRect:rect, angle: ang_, alpha:a_)
                
                if !self.appendPixelBufferForImageAtURL(overImage, pixelBufferAdaptor: pixelBufferAdaptor, presentationTime: presentationTime) {
                    print("Error converting images to video: AVAssetWriterInputPixelBufferAdapter failed to append pixel buffer")
                    return
                }
                
                frameCount += 1
            }
            
            // No more images to add? End video.
            if (frameCount >= numImages) {
                writerInput.markAsFinished()
                assetWriter.finishWritingWithCompletionHandler {
                    if (assetWriter.error != nil) {
                        print("Error converting images to video: \(assetWriter.error)")
                    } else {
                        //self.saveVideoToLibrary(NSURL(fileURLWithPath: videoPath))
                        print("Converted images to movie @ \(videoPath)")
                        self.events.trigger("sticker_finish", information: videoPath)
                        
                    }
                }
            }
        })
    }
    
    
    func createAssetWriter(path: String, size: CGSize) -> AVAssetWriter? {
        // Convert <path> to NSURL object
        let pathURL = NSURL(fileURLWithPath: path)
        
        // Return new asset writer or nil
        do {
            // Create asset writer
            let newWriter = try AVAssetWriter(URL: pathURL, fileType: AVFileTypeMPEG4)
            
            // Define settings for video input
            let videoSettings: [String : AnyObject] = [
                AVVideoCodecKey  : AVVideoCodecH264,
                AVVideoWidthKey  : size.width,
                AVVideoHeightKey : size.height,
                AVVideoCompressionPropertiesKey:
                    [
                        //AVVideoAverageBitRateKey: 2500000,
                        AVVideoProfileLevelKey: AVVideoProfileLevelH264MainAutoLevel
                    ]
                ]
            
            // Add video input to writer
            let assetWriterVideoInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: videoSettings)
            newWriter.addInput(assetWriterVideoInput)
            
            // Return writer
            print("Created asset writer for \(size.width)x\(size.height) video")
            return newWriter
        } catch {
            print("Error creating asset writer: \(error)")
            return nil
        }
    }
    
    
    func appendPixelBufferForImageAtURL(image: UIImage, pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor, presentationTime: CMTime) -> Bool {
        var appendSucceeded = false
        
        autoreleasepool {
            if  let pixelBufferPool = pixelBufferAdaptor.pixelBufferPool {
                let pixelBufferPointer = UnsafeMutablePointer<CVPixelBuffer?>.alloc(1)
                let status: CVReturn = CVPixelBufferPoolCreatePixelBuffer(
                    kCFAllocatorDefault,
                    pixelBufferPool,
                    pixelBufferPointer
                )
                
                if let pixelBuffer = pixelBufferPointer.memory where status == 0 {
                    fillPixelBufferFromImage(image, pixelBuffer: pixelBuffer)
                    
                    appendSucceeded = pixelBufferAdaptor.appendPixelBuffer(pixelBuffer, withPresentationTime: presentationTime)
                    pixelBufferPointer.destroy()
                } else {
                    NSLog("Error: Failed to allocate pixel buffer from pool")
                }
                
                pixelBufferPointer.dealloc(1)
            }
        }
        
        return appendSucceeded
    }
    
    
    func fillPixelBufferFromImage(image: UIImage, pixelBuffer: CVPixelBufferRef) {
        CVPixelBufferLockBaseAddress(pixelBuffer, 0)
        
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        
        // Create CGBitmapContext
        let context = CGBitmapContextCreate(
            pixelData,
            Int(image.size.width),
            Int(image.size.height),
            8,
            CVPixelBufferGetBytesPerRow(pixelBuffer),
            rgbColorSpace,
            CGImageAlphaInfo.PremultipliedFirst.rawValue
        )
        
        // Draw image into context
        CGContextDrawImage(context, CGRectMake(0, 0, image.size.width, image.size.height), image.CGImage)
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0)
    }
    
    
    func saveVideoToLibrary(videoURL: NSURL) {
        let assetsLib = ALAssetsLibrary()
        assetsLib.writeVideoAtPathToSavedPhotosAlbum(videoURL, completionBlock: {
            (nsurl, error) -> Void in
            print("Transfer video to library finished.")
            //self.videoUploader.uploadVideo(file_url.path!, vid: "test")
           // self.events.trigger("sticker_finish", information: self.outputPath)
            
        })
    }


}
