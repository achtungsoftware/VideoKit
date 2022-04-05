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
    
    public static func mutate(videoUrl: URL, config: Config = Config(), callback: @escaping ( _ result: Result ) -> ()) {
        
        let asset = AVURLAsset(url: videoUrl, options: nil)
        
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            return callback(.error("ERROR INIT ASSET TRACK"))
        }
        
        if let limitBitrate = config.limitBitrate, videoTrack.estimatedDataRate > Float(limitBitrate) {
            let outputVideoUrl = URL(fileURLWithPath: getOutputPath(UUID().uuidString))
            _ = compress(videoToCompress: videoUrl, destinationPath: outputVideoUrl, size: nil, compressionTransform: .keepSame, compressionConfig: .init(videoBitrate: limitBitrate, avVideoProfileLevel: AVVideoProfileLevelH264High41, audioSampleRate: 22050, audioBitrate: 80000),
                         completionHandler: { path in
                _procMutate(videoUrl: path, config: config, callback: callback)
            },
                         errorHandler: { e in
                return callback(.error("UNKNOWN ERROR"))
            },
                         cancelHandler: {
                return callback(.error("CANCEL"))
            }
            )
        }else {
            _procMutate(videoUrl: videoUrl, config: config, callback: callback)
        }
    }
    
    private static func _procMutate(videoUrl: URL, config: Config = Config(), callback: @escaping ( _ result: Result ) -> ()) {
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
        let exporter = AVAssetExportSession(asset: asset, presetName: config.quality.get())
        
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
        var quality: Quality
        var limitLength: Double?
        var cropRect: CGRect?
        var limitFPS: Int32?
        var limitBitrate: Int?
        
        public init(_ quality: Quality = .preset1920x1080,
                    limitLength: Double? = nil,
                    cropRect: CGRect? = nil,
                    limitFPS: Int32? = nil,
                    limitBitrate: Int? = nil) {
            self.quality = quality
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
    
    enum Quality {
        case preset640x480
        case preset960x540
        case preset1280x720
        case preset1920x1080
        case preset3840x2160
        
        func get() -> String {
            switch self {
            case .preset640x480:
                return AVAssetExportPreset640x480
            case .preset960x540:
                return AVAssetExportPreset960x540
            case .preset1280x720:
                return AVAssetExportPreset1280x720
            case .preset1920x1080:
                return AVAssetExportPreset1920x1080
            case .preset3840x2160:
                return AVAssetExportPreset3840x2160
            }
        }
    }
}
