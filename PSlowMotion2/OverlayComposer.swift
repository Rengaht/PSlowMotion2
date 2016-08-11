//
//  OverlayComposer.swift
//  PSlowMotion2
//
//  Created by Reng Tsai on 2016/8/10.
//  Copyright © 2016年 Reng Tsai. All rights reserved.
//

import Foundation
import AVFoundation
import AssetsLibrary
import UIKit


class OverlayComposer : NSObject{
    
    let events=EventManager()
    
    var arr_pos_x:NSMutableArray=[]
    var arr_pos_y:NSMutableArray=[]
    
    var arr_frame:NSMutableArray!
    var num_frame:Int!
    
    private var outputPath: String {
        get {
            let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
            let documentsDirectory = paths[0] as String
            let filePath : String = "\(documentsDirectory)/overlay.mp4"
            return filePath
        }
    }
    override init(){
        self.num_frame=480
    }
    
    func loadOverlayFrames(){
        arr_frame=NSMutableArray.init(capacity:num_frame)
        for i in 0...num_frame{
            let name_=String.init(format:"%05d",i)
            let path_ = NSBundle.mainBundle().pathForResource("slow motion effect_\(name_)", ofType: "png",inDirectory: "effect")
            let data = NSData(contentsOfURL:NSURL(fileURLWithPath:path_!))
            arr_frame.addObject(UIImage(data:data!)!)
        }
        
    }
    
    
    func createOverlayImage(overlayImage:UIImage,backImage:UIImage)->UIImage{
        
        var filteredImage:UIImage!
        autoreleasepool{
       
            let ciBackImage=CIImage(image: backImage)
            let ciOverlayImage=CIImage(image: overlayImage)
        
            let outputImage=ciBackImage?.imageByApplyingFilter("CIScreenBlendMode", withInputParameters:[
                "inputBackgroundImage":ciBackImage!,
                "inputImage":ciOverlayImage!
            ])
        
            let newSize = CGSizeMake(1280,720) // set this to what you need
            UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
            UIImage(CIImage: outputImage!).drawInRect(CGRectMake(0, 0, newSize.width, newSize.height))
        
            filteredImage=UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
      
        }
        
        return filteredImage
            
    
        
    }
    
    func composeOverlayVideo(inputPath:String){
        
        print("compose overlay...")
        
        
        let video_asset = AVAsset(URL: NSURL(fileURLWithPath: inputPath))
        let video_track=video_asset.tracksWithMediaType(AVMediaTypeVideo)[0]
        var track_output:AVAssetReaderTrackOutput!
        var video_reader:AVAssetReader!
        
        
        do{
            
            try video_reader=AVAssetReader(asset: video_asset)
            
            let settings : [String : AnyObject] = [
                kCVPixelBufferPixelFormatTypeKey as String : Int(kCVPixelFormatType_32ARGB)]
                
            track_output=try AVAssetReaderTrackOutput(track: video_track, outputSettings:settings)
            video_reader.addOutput(track_output)
            
            print("record video duration=\(video_asset.duration)")
            
            //        let imageGenerator = AVAssetImageGenerator(asset: asset)
            //        imageGenerator.appliesPreferredTrackTransform = true
        }catch{
            print(error)
        }
        
        
        let manager = NSFileManager()
        do{
            try manager.removeItemAtPath(self.outputPath)
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
        //let numImages = 150
        writerInput.requestMediaDataWhenReadyOnQueue(mediaQueue, usingBlock: { () -> Void in
            // Append unadded images to video but only while input ready
            if (writerInput.readyForMoreMediaData){
                
                if video_reader.startReading() {
                
                    var videoframe:UIImage!
                    while(video_reader.status==AVAssetReaderStatus.Reading) {
                        
                        autoreleasepool{
                            
                            var sample:CMSampleBuffer!
                            
                            let lastFrameTime = CMTimeMake(Int64(frameCount), videoFPS)
                            let presentationTime = frameCount == 0 ? lastFrameTime : CMTimeAdd(lastFrameTime, frameDuration)
                            
                            
                            do{
                                if(video_reader.status==AVAssetReaderStatus.Reading) {
                                    sample=track_output.copyNextSampleBuffer()
                                }
                                
                                if sample==nil{
                                    print("nil sample buffer!")
                                }else{
                                    
                                    
                                    videoframe=self.imageFromSampleBuffer(sample!)
                            
                                    let overImage=self.createOverlayImage(self.arr_frame[frameCount] as! UIImage, backImage:videoframe)
                            
                                    if !self.appendPixelBufferForImageAtURL(overImage, pixelBufferAdaptor: pixelBufferAdaptor, presentationTime: presentationTime) {
                                        print("Error converting images to video: AVAssetWriterInputPixelBufferAdapter failed to append pixel buffer")
                                        return
                                    }
                            
                                    frameCount += 1
                                }
                            }catch{
                                print(error)
                            }
                        
                        }
                    }
                    
                    while(frameCount<self.num_frame){
                        
                        let lastFrameTime = CMTimeMake(Int64(frameCount), videoFPS)
                        let presentationTime = frameCount == 0 ? lastFrameTime : CMTimeAdd(lastFrameTime, frameDuration)
                        
                        let overImage=self.createOverlayImage(self.arr_frame[frameCount] as! UIImage, backImage:videoframe)
                        
                        if !self.appendPixelBufferForImageAtURL(overImage, pixelBufferAdaptor: pixelBufferAdaptor, presentationTime: presentationTime) {
                            print("Error converting images to video: AVAssetWriterInputPixelBufferAdapter failed to append pixel buffer")
                            return
                        }
                        
                        frameCount += 1
                    }
                    
                    
                }
                
                
            
            
                // No more images to add? End video.
                if (video_reader.status==AVAssetReaderStatus.Completed) {
                    writerInput.markAsFinished()
                    assetWriter.finishWritingWithCompletionHandler {
                        if (assetWriter.error != nil) {
                            print("Error converting images to video: \(assetWriter.error)")
                        } else {
                            print("Converted images to movie @ \(self.outputPath) mfr=\(frameCount)")
                            self.events.trigger("overlay_finish", information: self.outputPath)
                           // self.saveVideoToLibrary(NSURL(fileURLWithPath: self.outputPath))
                        }
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
            //print("Created asset writer for \(size.width)x\(size.height) video")
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
    
    func imageFromSampleBuffer(sample: CMSampleBuffer)->UIImage{
        
        var image:UIImage!
        
        if let imageBufferRef = CMSampleBufferGetImageBuffer(sample){
       
            CVPixelBufferLockBaseAddress(imageBufferRef, 0);
        
            let baseAddress = CVPixelBufferGetBaseAddress(imageBufferRef)
            let bytePerRow = CVPixelBufferGetBytesPerRow(imageBufferRef)
            let width = CVPixelBufferGetWidth(imageBufferRef)
            let height = CVPixelBufferGetHeight(imageBufferRef)
        
            let colorSpace = CGColorSpaceCreateDeviceRGB()
        
            let context = CGBitmapContextCreate(baseAddress, width, height, 8, bytePerRow, colorSpace, (CGImageAlphaInfo.PremultipliedFirst.rawValue))
        
            let cgImageRef = CGBitmapContextCreateImage(context)
            image = UIImage(CGImage: cgImageRef!)
            
            CVPixelBufferUnlockBaseAddress(imageBufferRef, 0);

        }
        return image
        
    }
    
    
}
