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

public extension URL {
    
    /// Try's to get a thumbnail from a video `URL`
    /// - Parameters:
    ///   - url: The video `URL`
    ///   - completion: The callback with `Optional` `UIImage`
    func videoGetThumbnail(completion: @escaping ((_ image: UIImage?) -> Void)) {
        let asset = AVURLAsset(url: self, options: nil)
        let avAssetImageGenerator = AVAssetImageGenerator(asset: asset)
        avAssetImageGenerator.appliesPreferredTrackTransform = true
        
        do {
            let cgThumbImage = try avAssetImageGenerator.copyCGImage(at: CMTimeMake(value: 0, timescale: 1), actualTime: nil)
            let thumbImage = UIImage(cgImage: cgThumbImage)
            
            completion(thumbImage)
        } catch {
            completion(nil)
        }
    }
    
    /// Gets the size from an video `URL`
    /// - Parameter url: The video `URL`
    /// - Returns: The size `CGSize`
    public static func videoGetSize(url: URL) -> CGSize? {
        guard let track = AVURLAsset(url: url).tracks(withMediaType: AVMediaType.video).first else { return nil }
        let size = track.naturalSize.applying(track.preferredTransform)
        return CGSize(width: abs(size.width), height: abs(size.height))
    }
}
