//
//  AVQueuePlayerWithOutput.swift
//  MyMTLTestApp
//
//

import AVFoundation

protocol MakeVideoOutputDelegate: Sendable {
    nonisolated func makeVideoOutput() -> AVPlayerItemVideoOutput
}

@MainActor
class AVQueuePlayerWithOutput: AVQueuePlayer {

    let videoOutputSettings: VideoOutputSettings
    
    init(videoOutputSettings: VideoOutputSettings) {
        self.videoOutputSettings = videoOutputSettings
        super.init()
    }
    
    override nonisolated func insert(_ item: AVPlayerItem, after afterItem: AVPlayerItem?) {
        if item.outputs.count > 0 {
            print("AVPlayerItem already has \(item.outputs.count) output: \(item.outputs.debugDescription)")
        } else {
            print("Creating video output for newly inserted AVPlayerItem")
            let videoOutput = AVPlayerItemVideoOutput(outputSettings: videoOutputSettings)
            item.add(videoOutput)
        }
        super.insert(item, after: afterItem)
    }
    
    override nonisolated private init() {
        videoOutputSettings = [:]
        super.init()
    }

    override nonisolated private init(url URL: URL) {
        videoOutputSettings = [:]
        super.init(url: URL)
    }
    
    override nonisolated private init(items: [AVPlayerItem]) {
        videoOutputSettings = [:]
        super.init(items: items)
    }
    
    override nonisolated private init(playerItem item: AVPlayerItem?) {
        videoOutputSettings = [:]
        super.init(playerItem: item)
    }
    
}
