//  Copyright © 2022 - present Julian Gerhards
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
import AVFoundation

public extension AVAssetTrack {
    
    /// Gets the ``VideoKit.Orientation`` for a video `AVAssetTrack`
    /// - Returns: ``VideoKit.Orientation``
    func orientation() -> VideoKit.Orientation {
        let t = self.preferredTransform
        let size = self.naturalSize
        
        if t.tx == 0 && t.ty == size.width { // PortraitUpsideDown
            return .down
        } else if t.tx == 0 && t.ty == 0 { // LandscapeRight
            return .right
        } else if size.width == t.tx && size.height == t.ty { // LandscapeLeft
            return .left
        } else {
            return .up
        }
    }
}
