//
//  APMPPlayerEntity.swift
//  NutshellPlayer
//
//  Created by Andy Zhang on 2026/2/24.
//

import AVFoundation
import RealityKit
import os.log

class APMPPlayerEntity: Entity, HasModel {
    private var logger = Logger(subsystem: "fun.NutshellPlayer", category: "APMPPlayerEntity")
    var provider: Playable?

    var renderer = AVSampleBufferVideoRenderer()

    var cachedDimensions: CMVideoDimensions?
    var cachedFormatDescription: CMFormatDescription?

    @MainActor
    func setup(provider: Playable) async {
        logger.info("Setting up player entity")
        self.provider = provider
        if let ffmpegVideoProvider = provider as? FFmpegVideo {
            logger.info("Setup video renderer")
            ffmpegVideoProvider.setVideoRenderer(renderer)
        }
        var videoPlayerComponent = VideoPlayerComponent(videoRenderer: renderer)
        videoPlayerComponent.desiredSpatialVideoMode = .spatial
        videoPlayerComponent.desiredViewingMode = .stereo
        videoPlayerComponent.desiredImmersiveViewingMode = .progressive
        self.components.set(videoPlayerComponent)

        if provider.videoOutput != nil {
            renderer.requestMediaDataWhenReady(on: DispatchQueue.global()) { [weak self] in
                while self?.renderer.isReadyForMoreMediaData ?? false {
                    if let sampleBuffer = self?.provider?.videoOutput?.copyNextSampleBuffer() {
                        var sampleBufferWithAPMP: CMReadySampleBuffer<CVReadOnlyPixelBuffer>?
                        switch sampleBuffer.content {
                        case .pixelBuffer(let pixelBuffer):
                            if let formatDescription = try? self?.getAPMPFormatDescription(for: pixelBuffer) {
                                sampleBufferWithAPMP = CMReadySampleBuffer<CVReadOnlyPixelBuffer>(
                                    pixelBuffer: pixelBuffer,
                                    formatDescription: formatDescription,
                                    presentationTimeStamp: sampleBuffer.presentationTimeStamp,
                                    duration: sampleBuffer.duration)
                            }
                        default:
                            self?.logger.error("Wrong type of sample buffer content. Expecting pixelBuffer.")
                            break
                        }
                        if sampleBufferWithAPMP != nil {
                            sampleBufferWithAPMP!.withUnsafeSampleBuffer() { [weak self] sbuf in
                                self?.renderer.enqueue(sbuf)
                            }
                        } else {
                            sampleBuffer.withUnsafeSampleBuffer() { [weak self] sbuf in
                                self?.renderer.enqueue(sbuf)
                            }
                        }
                    } else {
                        self?.logger.info("No more sample buffer")
                        self?.renderer.stopRequestingMediaData()
                        return
                    }
                }
            }
        }
    }

    @MainActor
    func cleanup() {
        logger.debug("Cleaning up resources.")
        self.components.removeAll()
        provider = nil
    }

    func setStereo(_ isStereo: Bool) {

    }

    var paused: Bool {
        get {
            !(provider?.isPlaying ?? false)
        }
        set {
            if newValue {
                provider?.pause()
            } else {
                provider?.play()
            }
        }
    }

    private func getAPMPFormatDescription(for pixelBuffer: CVReadOnlyPixelBuffer) throws -> CMFormatDescription {
        var dimensions: CMVideoDimensions?
        pixelBuffer.withUnsafeBuffer { buffer in
            let width = CVPixelBufferGetWidth(buffer)
            let height = CVPixelBufferGetHeight(buffer)
            dimensions = CMVideoDimensions(width: Int32(width), height: Int32(height))
        }

        if let cachedFormatDescription,
           let cachedDimensions,
           cachedDimensions.width == dimensions?.width,
           cachedDimensions.height == dimensions?.height {
            return cachedFormatDescription
        }

        let formatDescription = try createAPMPFormatDescription(for: pixelBuffer)

        cachedFormatDescription = formatDescription
        cachedDimensions = dimensions

        return formatDescription
    }

    private func createAPMPFormatDescription(for pixelBuffer: CVReadOnlyPixelBuffer) throws -> CMFormatDescription {
        let baseFormat = CMVideoFormatDescription(pixelBuffer: pixelBuffer)
        var extensions = baseFormat.extensions

        extensions[.viewPackingKind] = .viewPackingKind(.sideBySide)
        extensions[.projectionKind] = .projectionKind(.halfEquirectangular)

        return try CMVideoFormatDescription(
            videoCodecType: baseFormat.mediaSubType,
            width: Int(baseFormat.dimensions.width),
            height: Int(baseFormat.dimensions.height),
            extensions: extensions
        )
    }
}
