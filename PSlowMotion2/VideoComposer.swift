//
//  VideoComposer.swift
//  PSlowMotion2
//
//  Created by Reng Tsai on 2016/7/27.
//  Copyright © 2016年 Reng Tsai. All rights reserved.
//

import Foundation
import AVFoundation
import AssetsLibrary
import UIKit

class VideoComposer : NSObject{
    
    var STICKER_START_TIME=Double(33.5)
    
    let events=EventManager()
    
    
    var opening_asset:AVURLAsset!
    var ending_asset:AVURLAsset!
    var bgm_asset:AVURLAsset!
    
    var opening_track:AVAssetTrack!
    var ending_track:AVAssetTrack!
    var bgm_track:AVAssetTrack!
    
    
    var arr_pos_x:NSMutableArray=[]
    var arr_pos_y:NSMutableArray=[]
    
    
    private var combinePath: String {
        get {
            let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
            let documentsDirectory = paths[0] as String
            let filePath : String = "\(documentsDirectory)/combin.mp4"
            return filePath
        }
    }
    private var stickerPartPath: String {
        get {
            let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
            let documentsDirectory = paths[0] as String
            let filePath : String = "\(documentsDirectory)/sticker.mp4"
            return filePath
        }
    }
    
    
    override init(){
        let openPath = NSBundle.mainBundle().pathForResource("extra_open", ofType: "mov")
        opening_asset=AVURLAsset(URL:NSURL.fileURLWithPath(openPath!),options:nil)
        opening_track=opening_asset.tracksWithMediaType(AVMediaTypeVideo)[0]
        
        let endPath = NSBundle.mainBundle().pathForResource("extra_end", ofType: "mov")
        ending_asset=AVURLAsset(URL:NSURL.fileURLWithPath(endPath!),options:nil)
        ending_track=ending_asset.tracksWithMediaType(AVMediaTypeVideo)[0]
        
        let bgmPath = NSBundle.mainBundle().pathForResource("full_v3", ofType: "mp3")
        bgm_asset=AVURLAsset(URL:NSURL.fileURLWithPath(bgmPath!),options:nil)
        bgm_track=bgm_asset.tracksWithMediaType(AVMediaTypeAudio)[0]
        
        
    }
    
    
    func combineVideo(input_path:String,sticker_path:String){
        
        print("combine video...")
        
        
        
        var composition = AVMutableComposition()
        let trackVideo:AVMutableCompositionTrack = composition.addMutableTrackWithMediaType(AVMediaTypeVideo, preferredTrackID: CMPersistentTrackID())
        
        
        let trackAudio:AVMutableCompositionTrack = composition.addMutableTrackWithMediaType(AVMediaTypeAudio, preferredTrackID: CMPersistentTrackID())
        var insertTime = kCMTimeZero
        
        let sourceAsset = AVURLAsset(URL: NSURL(fileURLWithPath: input_path), options: nil)
        let tracks = sourceAsset.tracksWithMediaType(AVMediaTypeVideo)
        
        let stickerAsset = AVURLAsset(URL: NSURL(fileURLWithPath: sticker_path), options: nil)
        let stickertracks = stickerAsset.tracksWithMediaType(AVMediaTypeVideo)
        
        
       // var endcut_time=CMTimeMake(26,24)
        let total_due=CMTimeAdd(CMTimeAdd(opening_asset.duration,sourceAsset.duration),stickerAsset.duration)
        
        do{
            
            try trackVideo.insertTimeRange(CMTimeRangeMake(kCMTimeZero,opening_asset.duration), ofTrack: opening_track, atTime: insertTime)
            insertTime=CMTimeAdd(insertTime, opening_asset.duration)
            
            
                try trackVideo.insertTimeRange(CMTimeRangeMake(kCMTimeZero,sourceAsset.duration), ofTrack: tracks[0], atTime: insertTime)
                insertTime=CMTimeAdd(insertTime, sourceAsset.duration)
            
            
            try trackVideo.insertTimeRange(CMTimeRangeMake(kCMTimeZero,stickerAsset.duration), ofTrack: stickertracks[0], atTime: insertTime)
            
            
            try trackAudio.insertTimeRange(CMTimeRangeMake(kCMTimeZero,total_due), ofTrack: bgm_track, atTime: kCMTimeZero)
            
            
        }catch{
            print(error)
        }
        
        let opa_animation=CAKeyframeAnimation(keyPath: "opacity")
        //move_animation_y.keyTimes=[0,0.14634,0.5122,0.7561,1]
        opa_animation.keyTimes=[0,0.05,0.95,1]
        opa_animation.values=[0,1,1,0]
        opa_animation.duration=CMTimeGetSeconds(sourceAsset.duration)
        opa_animation.beginTime=CMTimeGetSeconds(opening_asset.duration)
        opa_animation.removedOnCompletion=true
        opa_animation.fillMode=kCAFillModeForwards
        
        let video_layer=CALayer()
        let parent_layer=CALayer()
        video_layer.frame=CGRectMake(0, 0, 1280, 720)
        video_layer.addAnimation(opa_animation, forKey: "fade-in-out")
        parent_layer.frame=CGRectMake(0, 0, 1280, 720)
        parent_layer.backgroundColor=UIColor.whiteColor().CGColor
        
        parent_layer.addSublayer(video_layer)
        
        
        let video_composition=AVMutableVideoComposition()
        video_composition.renderSize=CGSizeMake(1280, 720)
        video_composition.frameDuration=CMTimeMake(1,24)
        video_composition.animationTool=AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: video_layer, inLayer: parent_layer)
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRangeMake(kCMTimeZero, total_due)
        let video_track = composition.tracksWithMediaType(AVMediaTypeVideo)[0] as AVAssetTrack
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack:video_track);
        
        instruction.layerInstructions = [layerInstruction]
        video_composition.instructions = [instruction];
        
        
        
        //make sure no other file where this one will be saved
        let manager = NSFileManager()
        do{
            try manager.removeItemAtPath(self.combinePath)
        }catch{
            print("file doesn't exist or couldn't remove file at path")
        }
        
        //let completeMovie = outputPath.stringByAppendingPathComponent("movie.mov")
        let completeMovieUrl = NSURL(fileURLWithPath: self.combinePath)
        
        let encoder=SDAVAssetExportSession(asset: composition)
        encoder.videoComposition=video_composition
        
        encoder.outputURL=completeMovieUrl
        encoder.outputFileType=AVFileTypeMPEG4
        encoder.videoSettings = [
            AVVideoCodecKey: AVVideoCodecH264,
            AVVideoWidthKey: 1280,
            AVVideoHeightKey: 720,
            AVVideoCompressionPropertiesKey:
                [
                    //AVVideoAverageBitRateKey: 2200000,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264MainAutoLevel,
            ],
        ]
        encoder.audioSettings = [
            AVFormatIDKey: Int(Int32(kAudioFormatMPEG4AAC)),
            AVNumberOfChannelsKey: 2,
            AVSampleRateKey: 44100,
            AVEncoderBitRateKey: 128000,
        ]
        encoder.exportAsynchronouslyWithCompletionHandler({
            switch encoder!.status{
            case  AVAssetExportSessionStatus.Failed:
                print("export failed: \(encoder!.error)")
            case AVAssetExportSessionStatus.Cancelled:
                print("export cancelled: \(encoder!.error)")
            default:
                print("export complete!")
                self.exportVideo(completeMovieUrl)
            }
        })
        
    }
    func exportVideo(file_url:NSURL){
        let assetsLib = ALAssetsLibrary()
         assetsLib.writeVideoAtPathToSavedPhotosAlbum(file_url, completionBlock: {
                                (nsurl, error) -> Void in
                                print("Transfer video to library finished.")
                                //self.videoUploader.uploadVideo(file_url.path!, vid: "test")
                                self.events.trigger("compose_finish", information: self.combinePath)
                            })
    }
    
    func composeEndingPart(sticker_img:UIImage){
        
        var composition = AVMutableComposition()
        let trackVideo:AVMutableCompositionTrack = composition.addMutableTrackWithMediaType(AVMediaTypeVideo, preferredTrackID: CMPersistentTrackID())
        do{
            try trackVideo.insertTimeRange(CMTimeRangeMake(kCMTimeZero,ending_asset.duration), ofTrack: ending_track, atTime: kCMTimeZero)
        }catch{
            
        }
        let video_size=composition.naturalSize
        
        let sw=CGFloat(502);
        let sticker_layer=CALayer()
        sticker_layer.contents=sticker_img.CGImage
        //sticker_layer.frame=CGRectMake(0, 0, video_size.width, video_size.height)
        sticker_layer.opacity=0.0
        sticker_layer.frame=CGRectMake(623,720-336,sw,sw)
        sticker_layer.geometryFlipped=true
        //sticker_layer.beginTime=self.STICKER_START_TIME
        
        let linear_anim=CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        
        let move_animation_x=CAKeyframeAnimation(keyPath: "position.x")
        //move_animation_x.keyTimes=[0,0.08,0.474,0.737,1]
        
        let mkeyframe=arr_pos_x.count
        var keyframe=NSMutableArray()
        var tf=NSMutableArray()
        for i in 0...mkeyframe{
            keyframe.addObject(NSNumber(double: Double(i)*1.0/Double(mkeyframe)))
            tf.addObject(linear_anim)
            
        }
//        move_animation_x.keyTimes=[0,0.15634,0.528,0.7561,1]
//        move_animation_x.values=[623,623,502,693,636]
//        move_animation_x.timingFunctions=[linear_anim,linear_anim,linear_anim,linear_anim]
        
        
        
        move_animation_x.keyTimes=NSArray(array: keyframe) as! [NSNumber]
        move_animation_x.values=arr_pos_x as! [NSNumber]
        move_animation_x.timingFunctions=NSArray(array: tf) as! [CAMediaTimingFunction]
       
        move_animation_x.duration=1.33333
        move_animation_x.beginTime=3.3333
        move_animation_x.removedOnCompletion=false
        move_animation_x.fillMode=kCAFillModeForwards
        
        
        let move_animation_y=CAKeyframeAnimation(keyPath: "position.y")
        //move_animation_y.keyTimes=[0,0.14634,0.5122,0.7561,1]
        //move_animation_y.keyTimes=[0,0.15634,0.528,0.7561,1]
        //move_animation_y.values=[720-336,720-336,720-336,720-348,720-348]
//        move_animation_y.timingFunctions=[linear_anim,linear_anim,linear_anim,linear_anim]
        move_animation_y.keyTimes=NSArray(array: keyframe) as! [NSNumber]
        move_animation_y.values=arr_pos_y as! [NSNumber]
        move_animation_y.timingFunctions=NSArray(array: tf) as! [CAMediaTimingFunction]
        
        move_animation_y.duration=1.3333
        move_animation_y.beginTime=3.3333
        move_animation_y.removedOnCompletion=false
        move_animation_y.fillMode=kCAFillModeForwards
        
        
        
        let opa_animation=CABasicAnimation(keyPath: "opacity")
        opa_animation.fromValue=0.0
        opa_animation.toValue=1.0
        opa_animation.beginTime=3.3333
        opa_animation.duration=0.1
        opa_animation.removedOnCompletion=false
        opa_animation.fillMode=kCAFillModeForwards
        
        sticker_layer.addAnimation(move_animation_x, forKey: "sticker_move_x")
        sticker_layer.addAnimation(move_animation_y, forKey: "sticker_move_y")
//        sticker_layer.addAnimation(rotate_animation, forKey: "rotate_move")
        sticker_layer.addAnimation(opa_animation, forKey: "opa_ani")
        
        let video_layer=CALayer()
        let parent_layer=CALayer()
        video_layer.frame=CGRectMake(0, 0, video_size.width, video_size.height)
        parent_layer.frame=CGRectMake(0, 0, video_size.width, video_size.height)
        parent_layer.addSublayer(video_layer)
        parent_layer.addSublayer(sticker_layer)
        //  parent_layer.addSublayer(titleLayer)
        
        let layer_composition=AVMutableVideoComposition()
        layer_composition.renderSize=video_size
        layer_composition.frameDuration=CMTimeMake(1,24)
        layer_composition.animationTool=AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: video_layer, inLayer: parent_layer)
        

        
        let instruction = AVMutableVideoCompositionInstruction()
        //print(composition.duration)
        
        instruction.timeRange = CMTimeRangeMake(kCMTimeZero, composition.duration)
        let video_track = composition.tracksWithMediaType(AVMediaTypeVideo)[0] as AVAssetTrack
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack:video_track);
        
        instruction.layerInstructions = [layerInstruction]
        layer_composition.instructions = [instruction];
        
        
        //make sure no other file where this one will be saved
        let manager = NSFileManager()
        do{
            try manager.removeItemAtPath(self.stickerPartPath)
        }catch{
            print("file doesn't exist or couldn't remove file at path")
        }
        
        //let completeMovie = outputPath.stringByAppendingPathComponent("movie.mov")
        let completeMovieUrl = NSURL(fileURLWithPath: self.stickerPartPath)
        
        let encoder=SDAVAssetExportSession(asset: composition)
        encoder.videoComposition=layer_composition
        
        encoder.outputURL=completeMovieUrl
        encoder.outputFileType=AVFileTypeMPEG4
        encoder.videoSettings = [
            AVVideoCodecKey: AVVideoCodecH264,
            AVVideoWidthKey: 1280,
            AVVideoHeightKey: 720,
            AVVideoCompressionPropertiesKey:
                [
                    //AVVideoAverageBitRateKey: 2300000,
              //      AVVideoProfileLevelKey: AVVideoProfileLevelH264Baseline31
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264MainAutoLevel
            ],
        ]
        encoder.audioSettings = [
            AVFormatIDKey: Int(Int32(kAudioFormatMPEG4AAC)),
            AVNumberOfChannelsKey: 2,
            AVSampleRateKey: 44100,
            AVEncoderBitRateKey: 128000,
        ]
        encoder.exportAsynchronouslyWithCompletionHandler({
            switch encoder!.status{
            case  AVAssetExportSessionStatus.Failed:
                print("export failed: \(encoder!.error)")
            case AVAssetExportSessionStatus.Cancelled:
                print("export cancelled: \(encoder!.error)")
            default:
                print("export complete!")
            //    self.exportVideo(completeMovieUrl)
                self.events.trigger("ending_finish", information: self.stickerPartPath)
            }
        })
        
    }
    
}