//
//  CameraEngine.swift
//  naruhodo
//
//  Created by FUJIKI TAKESHI on 2014/11/10.
//  Copyright (c) 2014年 Takeshi Fujiki. All rights reserved.
//

import Foundation
import AVFoundation
import AssetsLibrary
import UIKit


class SlowCameraEngine : NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate{
    
    let INPUT_FPS:Int32=240
    let OUTPUT_FPS:Int32=30
    let REQUIRED_FRAME:Int64=480
    
    let events=EventManager()
    
    
    class SlowVideoWriter : NSObject {
        var fileWriter: AVAssetWriter!
        var videoInput: AVAssetWriterInput!
        var audioInput: AVAssetWriterInput!
        var pixelAdapter:AVAssetWriterInputPixelBufferAdaptor!
        
        
        init(fileUrl:NSURL!, height:Int, width:Int, channels:Int, samples:Float64){
            
            fileWriter = try? AVAssetWriter(URL: fileUrl, fileType: AVFileTypeMPEG4)
            
            let videoOutputSettings: Dictionary<String, AnyObject> = [
                AVVideoCodecKey : AVVideoCodecH264,
                AVVideoWidthKey : width,
                AVVideoHeightKey : height
            ]
            videoInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: videoOutputSettings)
            videoInput.expectsMediaDataInRealTime = true
            //videoInput.transform = CGAffineTransformMakeRotation(CGFloat(M_PI))
            fileWriter.addInput(videoInput)
            
//            let sourceBufferAttributes : [String : AnyObject] = [
//                kCVPixelBufferPixelFormatTypeKey as String : Int(kCVPixelFormatType_32ARGB),
//                kCVPixelBufferWidthKey as String : width,
//                kCVPixelBufferHeightKey as String :height,
//                ]
//            pixelAdapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput, sourcePixelBufferAttributes: sourceBufferAttributes)
            
            
//            let audioOutputSettings: Dictionary<String, AnyObject> = [
//                AVFormatIDKey : Int(kAudioFormatMPEG4AAC),
//                AVNumberOfChannelsKey : channels,
//                AVSampleRateKey : samples,
//                AVEncoderBitRateKey : 128000
//            ]
//            audioInput = AVAssetWriterInput(mediaType: AVMediaTypeAudio, outputSettings: audioOutputSettings)
//            audioInput.expectsMediaDataInRealTime = true
//            fileWriter.addInput(audioInput)
            
        }
        
        
        
        func write(sample: CMSampleBufferRef, isVideo: Bool){
            if CMSampleBufferDataIsReady(sample) {
                if fileWriter.status == AVAssetWriterStatus.Unknown {
                    print("Start writing, isVideo = \(isVideo), status = \(fileWriter.status.rawValue)")
                    let startTime = CMSampleBufferGetPresentationTimeStamp(sample)
                    fileWriter.startWriting()
                    fileWriter.startSessionAtSourceTime(startTime)
                }
                if fileWriter.status == AVAssetWriterStatus.Failed {
                    print("Error occured, isVideo = \(isVideo), status = \(fileWriter.status.rawValue), \(fileWriter.error!.localizedDescription)")
                    return
                }
                if isVideo {
                    if videoInput.readyForMoreMediaData {
                        videoInput.appendSampleBuffer(sample)
                    }
                }else{
                    if audioInput.readyForMoreMediaData {
                        audioInput.appendSampleBuffer(sample)
                    }
                }
            }
        }
        
        func finish(callback: Void -> Void){
            videoInput.markAsFinished()
            fileWriter.finishWritingWithCompletionHandler(callback)
        }
       
        
        
    }
    
    let captureSession = AVCaptureSession()
    var isCapturing = false
    let slowRatio = 2
    
    
    private let videoDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
    private let audioDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeAudio)
    private var videoWriter : SlowVideoWriter?
    
    private var height = 0
    private var width = 0
    
    private let recordingQueue = dispatch_queue_create("com.takecian.RecordingQueue", DISPATCH_QUEUE_SERIAL)

    private var currentFrameCount: Int64 = 0
    private var dropFrameCount: Int64 = 0
    
    private var recordPath: String {
        get {
            let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
            let documentsDirectory = paths[0] as String
            let filePath : String = "\(documentsDirectory)/record.mov"
            return filePath
        }
    }
    
    
    private var filePathUrl: NSURL {
        get {
            return NSURL(fileURLWithPath: recordPath)
        }
    }
    
    func startup(){
        
//        do{
//            try videoDevice.lockForConfiguration()
//            videoDevice.focusMode=AVCaptureFocusMode.ContinuousAutoFocus
//            videoDevice.focusPointOfInterest=CGPointMake(0.5,0.5)
//            videoDevice.unlockForConfiguration()
//        }catch{
//            print("setautofocus locked\(error)")
//        }
        
        
        
        captureSession.beginConfiguration()
        captureSession.sessionPreset = AVCaptureSessionPreset1280x720
        captureSession.commitConfiguration()
        
        
        let videoInput = try! AVCaptureDeviceInput(device: videoDevice) as AVCaptureDeviceInput
        captureSession.addInput(videoInput)
        
        
//        let audioInput = try! AVCaptureDeviceInput(device: audioDevice) as AVCaptureDeviceInput
//        captureSession.addInput(audioInput)
        
        // video output
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.setSampleBufferDelegate(self, queue: recordingQueue)
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey : Int(kCVPixelFormatType_32BGRA)
        ]
        
        
        captureSession.addOutput(videoDataOutput)
        
        let conn=videoDataOutput.connectionWithMediaType(AVMediaTypeVideo)
        conn.videoOrientation=AVCaptureVideoOrientation.LandscapeRight
        
        
        height = videoDataOutput.videoSettings["Height"] as! Int!
        width = videoDataOutput.videoSettings["Width"] as! Int!
        
        // audio output
//        let audioDataOutput = AVCaptureAudioDataOutput()
//        audioDataOutput.setSampleBufferDelegate(self, queue: recordingQueue)
//        captureSession.addOutput(audioDataOutput)
     
        configFormat()
        
        
        captureSession.startRunning()
    }
    func configFormat(){
        
        var selectedFormat:AVCaptureDeviceFormat!
        var selectedRange:AVFrameRateRange!
        var maxWidth:Int32=0
        
        for format in videoDevice.formats {
            let ranges = format.videoSupportedFrameRateRanges as! [AVFrameRateRange]
            //var frameRates = ranges[0]
            for range in ranges{
                let desc = format.formatDescription!
                let dimensions = CMVideoFormatDescriptionGetDimensions(desc)
                let width = dimensions.width
                
                let desireFPS:Float64=Double(self.INPUT_FPS)
                
                if (range.minFrameRate<=desireFPS && range.maxFrameRate>=desireFPS && width>maxWidth){
                    
                    print("get framerate \(self.INPUT_FPS)!\(range)")
                    selectedFormat = format as! AVCaptureDeviceFormat
                    selectedRange=range
                    maxWidth=width
                }
            }
        }
        if let format=selectedFormat{
            do{
                try videoDevice.lockForConfiguration()
                videoDevice.activeFormat = format
                videoDevice.activeVideoMinFrameDuration = CMTimeMake(1,self.INPUT_FPS)
                videoDevice.activeVideoMaxFrameDuration = CMTimeMake(1,self.INPUT_FPS)
                videoDevice.focusMode = AVCaptureFocusMode.AutoFocus
                //videoDevice.focusMode=AVCaptureFocusMode.ContinuousAutoFocus
                videoDevice.focusPointOfInterest=CGPointMake(0.5,0.5)
                videoDevice.unlockForConfiguration()

            }catch{
                
            }
        }
        print("set fps= \(videoDevice.activeVideoMinFrameDuration)-\(videoDevice.activeVideoMaxFrameDuration)")
        
    }
    func shutdown(){
        captureSession.stopRunning()
    }

    func start(){
        if !isCapturing{
            //print("in")
            isCapturing = true
            setupWriter()
        }
    }
    func zoomIn(){
        do{
            try videoDevice.lockForConfiguration()
                let desiredZoomFactor = videoDevice.videoZoomFactor + 0.2;
                videoDevice.videoZoomFactor = max(1.0, min(desiredZoomFactor, videoDevice.activeFormat.videoMaxZoomFactor));
            videoDevice.unlockForConfiguration()
        }catch{
            print(error)
        }
    }
    func zoomOut(){
        do{
            try videoDevice.lockForConfiguration()
            let desiredZoomFactor = videoDevice.videoZoomFactor - 0.2;
            videoDevice.videoZoomFactor = max(desiredZoomFactor,1.0);
            videoDevice.unlockForConfiguration()
        }catch{
            print(error)
        }
    }
    
    func stop(){
        if isCapturing{
            isCapturing = false
            print("total frame= \(self.currentFrameCount) drop=\(self.dropFrameCount)")
            
            
            
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                //print("in")
                self.videoWriter!.finish { () -> Void in
                    print("video writer finished.")
                    
                    self.videoWriter = nil
                    
                    //self.videoComposer.combineVideo(self.recordPath, output_path:self.combinePath)
                    
                    self.events.trigger("record_finish", information: self.recordPath)
                    
//                    let assetsLib = ALAssetsLibrary()
//                    assetsLib.writeVideoAtPathToSavedPhotosAlbum(self.filePathUrl, completionBlock: {
//                        (nsurl, error) -> Void in
//                        print("Transfer video to library finished.")
//                    })
                }
            })
        }
    }
    
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!){
        guard isCapturing else { return }
        
//        let isVideo = captureOutput is AVCaptureVideoDataOutput
//            
//        if videoWriter == nil && !isVideo {
//        }
//        if !isVideo {
//            return
//        }
        
        
        currentFrameCount += 1
        
        var buffer = sampleBuffer
        
        
        
        
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        buffer = setTimeStamp(sampleBuffer, newTime: CMTimeAdd(timestamp, CMTimeMake(1 * currentFrameCount, self.OUTPUT_FPS)))

        //print("write \(currentFrameCount)")
        videoWriter?.write(buffer, isVideo: true)
        
        if currentFrameCount==self.REQUIRED_FRAME { self.stop() }
        
    }
    func captureOutput(captureOutput: AVCaptureOutput!, didDropSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        dropFrameCount+=1
    }
    
    private func setTimeStamp(sample: CMSampleBufferRef, newTime: CMTime) -> CMSampleBufferRef {
        var count: CMItemCount = 0
        CMSampleBufferGetSampleTimingInfoArray(sample, 0, nil, &count);
        var info = [CMSampleTimingInfo](count: count, repeatedValue: CMSampleTimingInfo(duration: CMTimeMake(0, 0), presentationTimeStamp: CMTimeMake(0, 0), decodeTimeStamp: CMTimeMake(0, 0)))
        CMSampleBufferGetSampleTimingInfoArray(sample, count, &info, &count);
        
        for i in 0..<count {
            info[i].decodeTimeStamp = newTime
            info[i].presentationTimeStamp = newTime
        }
        
        var out: CMSampleBuffer?
        CMSampleBufferCreateCopyWithNewTiming(nil, sample, count, &info, &out);
        return out!
    }
    
    private func setupWriter(){
        if videoWriter == nil {
            let fileManager = NSFileManager()
            if fileManager.fileExistsAtPath(recordPath) {
                do {
                    try fileManager.removeItemAtPath(recordPath)
                } catch _ {
                }
            }
            
//            let fmt = CMSampleBufferGetFormatDescription(sampleBuffer)
//            let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(fmt!)
            
            let manager = NSFileManager()
            do{
                try manager.removeItemAtPath(self.recordPath)
            }catch{
                print("file doesn't exist or couldn't remove file at path")
            }
            
            print("setup writer")
            currentFrameCount=0
            videoWriter = SlowVideoWriter(
                fileUrl: filePathUrl,
                height: height, width: width,
                channels: 0,
                samples: 0
            )
        }
    }
    func getOutputPath()->String{
        return self.filePathUrl.absoluteString
    }
    
    func setFocusAt(fx:CGFloat, fy:CGFloat){
        do{
        
            try videoDevice.lockForConfiguration()
            videoDevice.focusMode=AVCaptureFocusMode.AutoFocus
            videoDevice.focusPointOfInterest=CGPointMake(fx, fy)
            //videoDevice.focusMode=AVCaptureFocusMode.Locked
            videoDevice.unlockForConfiguration()
        }catch{
            print("set focus error: \(error)")
        }
        
    }
    
    
    
}
