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

internal class Compressor {
    var assetWriter: AVAssetWriter?
    var assetReader: AVAssetReader?
    
    func compress(_ videoUrl: URL, bitrate: Int, config: VideoKit.Config, completion: @escaping (URL) -> Void) {
        
        let asset = AVURLAsset(url: videoUrl, options: nil)
        
        var audioFinished = false
        var videoFinished = false
        
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
        
        let videoSettings: [String: Any] = [
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitrate
            ],
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoHeightKey: videoTrack.naturalSize.height,
            AVVideoWidthKey: videoTrack.naturalSize.width,
            AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill
        ]
        
        let audioSettings: [String: Any] = [
            AVFormatIDKey : kAudioFormatMPEG4AAC,
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
                self.assetWriter?.finishWriting {
                    if let assetWriter = self.assetWriter {
                        do {
                            let data = try Data(contentsOf: assetWriter.outputURL)
                            print("compressFile -file size after compression: \(Double(data.count / 1048576)) mb")
                        } catch let err as NSError {
                            print("compressFile Error: \(err.localizedDescription)")
                        }
                        
                        completion(assetWriter.outputURL)
                    }
                }
                
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
}
