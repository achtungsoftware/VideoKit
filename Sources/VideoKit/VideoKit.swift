//  Copyright © 2021 - present Julian Gerhards
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
//  GitHub https://github.com/knoggl/VideoKit
//

import Foundation
import AVKit

public class VideoKit {
    
    var assetWriter: AVAssetWriter!
    var assetWriterVideoInput: AVAssetWriterInput!
    var audioMicInput: AVAssetWriterInput!
    var videoURL: URL!
    var audioAppInput: AVAssetWriterInput!
    var channelLayout = AudioChannelLayout()
    var assetReader: AVAssetReader?
    
    private func compress(_ urlToCompress: URL, bitrate: Int, completion: @escaping (URL)->Void) {
        
        var audioFinished = false
        var videoFinished = false
        
        let asset = AVAsset(url: urlToCompress)
        
        do {
            assetReader = try AVAssetReader(asset: asset)
        } catch {
            assetReader = nil
        }
        
        guard let reader = assetReader else {
            print("Could not iniitalize asset reader probably failed its try catch")
            // show user error message/alert
            return
        }
        
        guard let videoTrack = asset.tracks(withMediaType: AVMediaType.video).first else { return }
        let videoReaderSettings: [String:Any] = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB]
        
        let assetReaderVideoOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: videoReaderSettings)
        
        var assetReaderAudioOutput: AVAssetReaderTrackOutput?
        if let audioTrack = asset.tracks(withMediaType: AVMediaType.audio).first {
            
            let audioReaderSettings: [String : Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2
            ]
            
            assetReaderAudioOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: audioReaderSettings)
            
            if reader.canAdd(assetReaderAudioOutput!) {
                reader.add(assetReaderAudioOutput!)
            } else {
                print("Couldn't add audio output reader")
                // show user error message/alert
                return
            }
        }
        
        if reader.canAdd(assetReaderVideoOutput) {
            reader.add(assetReaderVideoOutput)
        } else {
            print("Couldn't add video output reader")
            // show user error message/alert
            return
        }
        
        let videoSettings:[String:Any] = [
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: bitrate],
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoHeightKey: videoTrack.naturalSize.height,
            AVVideoWidthKey: videoTrack.naturalSize.width,
            AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill
        ]
        
        let audioSettings: [String:Any] = [AVFormatIDKey : kAudioFormatMPEG4AAC,
                                   AVNumberOfChannelsKey : 2,
                                         AVSampleRateKey : 44100.0,
                                      AVEncoderBitRateKey: 128000
        ]
        
        let audioInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: audioSettings)
        let videoInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings)
        videoInput.transform = videoTrack.preferredTransform
        
        let videoInputQueue = DispatchQueue(label: "videoQueue")
        let audioInputQueue = DispatchQueue(label: "audioQueue")
        
        do {
            assetWriter = try AVAssetWriter(outputURL: URL(fileURLWithPath: VideoKit.getOutputPath(UUID().uuidString)), fileType: AVFileType.mp4)
            
        } catch {
            assetWriter = nil
        }
        
        guard let writer = assetWriter else {
            print("assetWriter was nil")
            // show user error message/alert
            return
        }
        
        writer.shouldOptimizeForNetworkUse = true
        writer.add(videoInput)
        writer.add(audioInput)
        
        writer.startWriting()
        reader.startReading()
        writer.startSession(atSourceTime: CMTime.zero)
        
        let closeWriter: () -> Void = {
            if audioFinished && videoFinished {
                self.assetWriter?.finishWriting(completionHandler: { [weak self] in
                    
                    if let assetWriter = self?.assetWriter {
                        do {
                            let data = try Data(contentsOf: assetWriter.outputURL)
                            print("compressFile -file size after compression: \(Double(data.count / 1048576)) mb")
                        } catch let err as NSError {
                            print("compressFile Error: \(err.localizedDescription)")
                        }
                    }
                    
                    if let safeSelf = self, let assetWriter = safeSelf.assetWriter {
                        completion(assetWriter.outputURL)
                    }
                })
                
                self.assetReader?.cancelReading()
            }
        }
        
        audioInput.requestMediaDataWhenReady(on: audioInputQueue) {
            while(audioInput.isReadyForMoreMediaData) {
                if let cmSampleBuffer = assetReaderAudioOutput?.copyNextSampleBuffer() {
                    
                    audioInput.append(cmSampleBuffer)
                    
                } else {
                    audioInput.markAsFinished()
                    DispatchQueue.main.async {
                        audioFinished = true
                        closeWriter()
                    }
                    break
                }
            }
        }
        
        videoInput.requestMediaDataWhenReady(on: videoInputQueue) {
            // request data here
            while(videoInput.isReadyForMoreMediaData) {
                if let cmSampleBuffer = assetReaderVideoOutput.copyNextSampleBuffer() {
                    
                    videoInput.append(cmSampleBuffer)
                    
                } else {
                    videoInput.markAsFinished()
                    DispatchQueue.main.async {
                        videoFinished = true
                        closeWriter()
                    }
                    break
                }
            }
        }
    }
    
    public static func mutate(videoUrl: URL, config: Config = Config(), callback: @escaping ( _ result: Result ) -> ()) {
        
        let asset = AVURLAsset(url: videoUrl, options: nil)
        
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            return callback(.error("ERROR INIT ASSET TRACK"))
        }
        
        let bitrate = config.limitBitrate != nil ? videoTrack.estimatedDataRate > Float(config.limitBitrate!) ? Int(config.limitBitrate!) : Int(videoTrack.estimatedDataRate) : Int(videoTrack.estimatedDataRate)
        
        print(bitrate)
        
        let instance = VideoKit()
        
        instance.compress(videoUrl, bitrate: bitrate) { newUrl in
            cop(videoUrl: newUrl, config: config, callback: callback)
        }
    }
    
    private static func cop(videoUrl: URL, config: Config = Config(), callback: @escaping ( _ result: Result ) -> ()) {
        let asset = AVURLAsset(url: videoUrl, options: nil)
        
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            return callback(.error("ERROR INIT ASSET TRACK"))
        }
        
        let trackOrientation = videoTrack.orientation()
        let transformer = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        let videoComposition = AVMutableVideoComposition()
        
        if let limitFPS = config.limitFPS {
            videoComposition.frameDuration = CMTime(value: 1, timescale: limitFPS)
        }
        
        var finalTransform: CGAffineTransform = CGAffineTransform.identity
        
        if let cropRect = config.cropRect {
            let cropOffX: CGFloat = cropRect.origin.x
            let cropOffY: CGFloat = cropRect.origin.y
            
            videoComposition.renderSize = cropRect.size
            
            switch trackOrientation {
            case .up:
                finalTransform = finalTransform
                    .translatedBy(x: videoTrack.naturalSize.height - cropOffX, y: 0 - cropOffY)
                    .rotated(by: CGFloat(deg2rad(90.0)))
            case .down:
                finalTransform = finalTransform
                    .translatedBy(x: 0 - cropOffX, y: videoTrack.naturalSize.width - cropOffY)
                    .rotated(by: CGFloat(deg2rad(-90.0)))
            case .right:
                finalTransform = finalTransform.translatedBy(x: 0 - cropOffX, y: 0 - cropOffY)
            case .left:
                finalTransform = finalTransform
                    .translatedBy(x: videoTrack.naturalSize.width - cropOffX, y: videoTrack.naturalSize.height - cropOffY)
                    .rotated(by: CGFloat(deg2rad(-180.0)))
            }
        }else {
            let s = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
            videoComposition.renderSize = CGSize(width: abs(s.width), height: abs(s.height))
            
            switch trackOrientation {
            case .up:
                finalTransform = finalTransform
                    .translatedBy(x: videoTrack.naturalSize.height, y: 0)
                    .rotated(by: CGFloat(deg2rad(90.0)))
            case .down:
                finalTransform = finalTransform
                    .translatedBy(x: 0, y: videoTrack.naturalSize.width)
                    .rotated(by: CGFloat(deg2rad(-90.0)))
            case .right:
                finalTransform = finalTransform.translatedBy(x: 0, y: 0)
            case .left:
                finalTransform = finalTransform
                    .translatedBy(x: videoTrack.naturalSize.width, y: videoTrack.naturalSize.height)
                    .rotated(by: CGFloat(deg2rad(-180.0)))
            }
        }
        
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: asset.duration)
        
        transformer.setTransform(finalTransform, at: .zero)
        instruction.layerInstructions = [transformer]
        videoComposition.instructions = [instruction]
        
        let outputVideoUrl = URL(fileURLWithPath: getOutputPath(UUID().uuidString))
        let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough)
        
        if let exporter = exporter {
            exporter.videoComposition = videoComposition
            exporter.outputURL = outputVideoUrl
            exporter.outputFileType = .mp4
            
            if let limitLength = config.limitLength {
                let startTime = CMTime(seconds: Double(0), preferredTimescale: 1000)
                
                var endTime: CMTime
                
                if asset.duration.seconds > limitLength {
                    endTime = CMTime(seconds: limitLength, preferredTimescale: 1000)
                }else {
                    endTime = CMTime(seconds: Double(asset.duration.seconds), preferredTimescale: 1000)
                }
                
                let timeRange = CMTimeRange(start: startTime, end: endTime)
                
                exporter.timeRange = timeRange
            }
            
            exporter.exportAsynchronously( completionHandler: { () -> Void in
                DispatchQueue.main.async {
                    callback(.success(outputVideoUrl))
                }
            })
        }else {
            callback(.error("EXPORTER INIT FAIL"))
        }
    }
    
    public static func getOutputPath(_ name: String) -> String {
        let documentPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true )[0] as NSString
        let outputPath = "\(documentPath)/\(name).mp4"
        return outputPath
    }
    
    /// Converts degrees to radians
    /// - Parameter number: Degrees number
    /// - Returns: The converted number
    public static func deg2rad(_ number: Double) -> Double {
        return number * .pi / 180
    }
}

public extension VideoKit {
    struct Config {
        var limitLength: Double?
        var cropRect: CGRect?
        var limitFPS: Int32?
        var limitBitrate: Int?
        
        public init(limitLength: Double? = nil,
                    cropRect: CGRect? = nil,
                    limitFPS: Int32? = nil,
                    limitBitrate: Int? = nil) {
            self.limitLength = limitLength
            self.cropRect = cropRect
            self.limitFPS = limitFPS
            self.limitBitrate = limitBitrate
        }
    }
    
    enum Orientation {
        case up, down, right, left
    }
    
    enum Result {
        case success(_ videoUrl: URL)
        case error(_ errorString: String)
    }
}
