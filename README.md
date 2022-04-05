# VideoKit

VideoKit is a high level layer on top of AVKit

How it works
```swift

// With this config, the video will get resized to 1920x1080p, the maximal length is 180 seconds, fps is limited to 30 with a max. bitrate of 2.500.000
let config = VideoKit.Config(.preset1920x1080, limitLength: 180, limitFPS: 30, limitBitrate: 2_500_000)

VideoKit.mutate(videoUrl: YOUR_VIDEO_URL, config: config) { result in
  switch result {
    case .success(let videoUrl):
      // DO SOMETHING WITH YOUR VIDEO
      break
    case .error(let errorString):
      print(errorString)
  }
}

// You can also crop videos with
let config = VideoKit.Config(.preset1920x1080, cropRect: CGRect(x: 0, y: 0, width: 100, height: 100))
```
