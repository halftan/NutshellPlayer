//
//  FFmpegVideo.swift
//  NutshellPlayer
//
//  Created by Andy Zhang on 2026/2/24.
//

import SFmpeg
import CoreMedia
import AVFoundation
import os.log

extension SFmpeg.AVAssetReaderTrackOutput: SampleBufferProvider {}

class FFmpegVideo: Playable {
    private let logger = Logger(subsystem: "fun.sfmpeg.player", category: "Player")

    private var asset: SFmpeg.AVAsset?

    private var reader: SFmpeg.AVAssetReader?

    var videoReaderOutput: SFmpeg.AVAssetReaderTrackOutput?
    var audioReaderOutput: SFmpeg.AVAssetReaderTrackOutput?

    var videoRenderer: AVSampleBufferVideoRenderer?
    var audioRenderer = AVSampleBufferAudioRenderer()

    var synchronizer = AVSampleBufferRenderSynchronizer()

    var isReading = false

    var url: URL?
    
    var isVideo: Bool = true

    var isFullRange: Bool = true

    var isHDR: Bool = false

    var bitDepth: BitDepth = .bit8

    var stereoType: SteroeType = .sbs

    var colorSpace: VideoColorSpace = .bt709

    var naturalSize: CGSize = .zero

    var aspectRatio: CGFloat = .defaultAspectRatio

    /// this property is not used in FFmpegVideo
    var videoOutputSettings: VideoOutputSettings = [:]

    var currentTime: TimeInterval = .zero

    var duration: TimeInterval = .zero

    var isEditingCurrentTime: Bool = false

    var isPlaying: Bool {
        get {
            synchronizer.rate != .zero
        }
    }

    public init() {
        synchronizer.setRate(.zero, time: .zero)
        synchronizer.addRenderer(audioRenderer)
    }

    public func setVideoRenderer(_ renderer: AVSampleBufferVideoRenderer) {
        synchronizer.addRenderer(renderer)
        self.videoRenderer = renderer
    }

    func seek(to: CMTime) async -> Bool {
        /// TODO: implement seek feature
        return false
    }
    
    func stop() async {
        await synchronizer.setRate(.zero, time: .zero)
        await cleanup()
    }
    
    func pause() {
        synchronizer.rate = .zero
    }

    var videoOutput: (any SampleBufferProvider)? {
        get {
            return videoReaderOutput
        }
    }

    private func startReading() {
        guard let reader, !isReading else { return }
        isReading = true
        reader.startReading()

        if audioReaderOutput != nil {
            audioRenderer.requestMediaDataWhenReady(on: DispatchQueue.global()) { [weak self] in
                while self?.audioRenderer.isReadyForMoreMediaData ?? false {
                    if let sampleBuffer = self?.audioReaderOutput?.copyNextSampleBuffer() {
                        self?.logger.debug("Retrieved audio frame@:\(sampleBuffer.presentationTimeStamp.seconds), duration: \(sampleBuffer.duration.seconds)")
                        sampleBuffer.withUnsafeSampleBuffer() { [weak self] sbuf in
                            self?.audioRenderer.enqueue(sbuf)
                        }
                    } else {
                        self?.logger.info("No more sample buffer")
                        self?.audioRenderer.stopRequestingMediaData()
                        return
                    }
                }
            }
        }
    }

    func play() {
        startReading()
        DispatchQueue.global().async { [weak self] in
            guard let self else { return }
            // wait until both output has sufficient media for playback
            while !(videoReaderOutput?.hasSufficientMediaDataForReliablePlaybackStart ?? true || audioReaderOutput?.hasSufficientMediaDataForReliablePlaybackStart ?? true) {
                Thread.sleep(forTimeInterval: 0.01)
            }
            while self.videoRenderer == nil {
                Thread.sleep(forTimeInterval: 0.01)
            }
            self.synchronizer.rate = 1.0
        }
    }
    
    func open(_ url: URL) async throws {
        self.url = url
        _ = url.startAccessingSecurityScopedResource()
        asset = try AVAsset(url: url)
        guard let asset else {
            throw VideoModelError.initializationFailed("Failed to create asset for url: \(url.absoluteString)")
        }
        reader = SFmpeg.AVAssetReader(asset: asset)
        guard let reader else {
            throw VideoModelError.initializationFailed("Failed to initialize asset reader")
        }
        if let videoTrack = try asset.loadTracks(withMediaType: .video).first {
            videoReaderOutput = SFmpeg.AVAssetReaderTrackOutput(track: videoTrack)
            reader.add(videoReaderOutput!)
        } else {
            logger.error("No video track found")
        }
        if let audioTrack = try asset.loadTracks(withMediaType: .audio).first {
            audioReaderOutput = SFmpeg.AVAssetReaderTrackOutput(track: audioTrack)
            reader.add(audioReaderOutput!)
        } else {
            logger.info("No audio track found")
        }
    }

    deinit {
        url?.stopAccessingSecurityScopedResource()
    }

    func cleanup() {
        reader?.stopReading()
        reader?.flush()
        url?.stopAccessingSecurityScopedResource()
        url = nil
        synchronizer.setRate(.zero, time: .zero)
        isReading = false
        videoRenderer?.stopRequestingMediaData()
        audioRenderer.stopRequestingMediaData()
        videoRenderer?.flush(removingDisplayedImage: true)
        audioRenderer.flush()
//        synchronizer = AVSampleBufferRenderSynchronizer()
//        audioRenderer = AVSampleBufferAudioRenderer()
//        videoRenderer = AVSampleBufferVideoRenderer()

        videoRenderer = nil
        videoReaderOutput = nil
        audioReaderOutput = nil
        reader = nil
        asset = nil
    }

}

