//
//  VideoModel+MediaProvider.swift
//  MyMTLTestApp
//
//

import AVFoundation
import os.log

extension VideoModel: Playable {

    struct SampleBufferOutput: SampleBufferProvider {
        let logger: Logger
        let videoOutput: AVPlayerItemVideoOutput

        init(videoOutput: AVPlayerItemVideoOutput, logger: Logger) {
            self.videoOutput = videoOutput
            self.logger = logger
        }

        func copyNextSampleBuffer() -> CMReadySampleBuffer<CMSampleBuffer.DynamicContent>? {

            let itemTime = videoOutput.itemTime(forHostTime: CACurrentMediaTime())
            if !videoOutput.hasNewPixelBuffer(forItemTime: itemTime) {
                return nil
            }
            guard let pixelBuffer = videoOutput.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil) else {
                logger.error("Failed to copy pixel buffer from video output")
                return nil
            }
            let roPixelBuffer = CVReadOnlyPixelBuffer(unsafeBuffer: pixelBuffer)
            return CMReadySampleBuffer<CMSampleBuffer.DynamicContent>(CMReadySampleBuffer(pixelBuffer: roPixelBuffer, presentationTimeStamp: itemTime))
        }
    }

    var videoRenderer: AVSampleBufferVideoRenderer {
        fatalError("Not implemented")
    }

    var videoOutput: SampleBufferProvider? {
        get {
            if let output = self.player?.currentItem?.outputs.first as? AVPlayerItemVideoOutput {
                return SampleBufferOutput(videoOutput: output, logger: logger)
            } else {
                return nil
            }
        }
    }

    func copyNextSampleBuffer() -> CMReadySampleBuffer<CMSampleBuffer.DynamicContent>? {
        logger.error("\(#function) is not implemented on NativeVideoModel")
        return nil
    }

    var aspectRatio: CGFloat {
        get {
            if naturalSize != .zero {
                return naturalSize.width / naturalSize.height
            }
            return .defaultAspectRatio
        }
    }

    nonisolated func seek(to: CMTime) async -> Bool {
        guard let player = await player else {
            print("Failed to obtain current player")
            return false
        }
        return await player.seek(to: to)
    }

    nonisolated func stop() async {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            pause()
            cleanup()
        }
    }

    func play() {
        guard let player = player else {
            print("Failed to obtain current player")
            return
        }
        player.play()
        displayLink?.isPaused = false
    }

    func pause() {
        guard let player = player else {
            print("Failed to obtain current player")
            return
        }
        player.pause()
        displayLink?.isPaused = true
    }
}

extension VideoModel {
    func makeDisplayLink(target: Any, selector: Selector) {
        if displayLink != nil {
            displayLink?.invalidate()
        }
        displayLink = CADisplayLink(target: target, selector: selector)
        displayLink!.add(to: .main, forMode: .common)
        displayLink!.preferredFrameRateRange = .init(minimum: 60.0,
                                                     maximum: 120.0,
                                                     preferred: max(min(frameRate, 120.0), 60.0))
    }
}
