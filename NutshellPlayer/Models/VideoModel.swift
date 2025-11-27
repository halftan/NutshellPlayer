//
//  VideoModel.swift
//  MyMTLTestApp
//
//

import AVKit
import Metal
import MetalKit
import SwiftUI
import UniformTypeIdentifiers
import Combine

extension CGFloat {
    static var defaultAspectRatio: Self {
        return 16.0 / 9.0
    }
}

@Observable
class VideoModel {
    var url: URL? {
        return _url
    }

    // Private backing storage for the url property
    private var _url: URL?

    private(set) var utType: UTType!
    private(set) var isVideo = true
    private(set) var stereoType: SteroeType = .defaultType
    private(set) var bitDepth: BitDepth = .bit8
    private(set) var isFullRange: Bool = false
    private(set) var isHDR: Bool = false
    private(set) var frameRate: Float = 0
    private(set) var colorSpace: VideoColorSpace = .unknown

    private(set) var isPlaying: Bool = false

    // Observable time properties
    private(set) var currentTime: TimeInterval = 0.0
    private(set) var duration: TimeInterval = 0.0
    var isEditingCurrentTime: Bool = false

    // Video track properties
    @ObservationIgnored
    private(set) var naturalSize: CGSize = .zero

    private var asset: AVAsset?
    var assetPreferredTransform: CGAffineTransform = .identity
    var videoColorProperties: [String: any Sendable] = [:]
    var videoOutputSettings: VideoOutputSettings = [:]

    var transferFunction: String {
        return videoColorProperties[AVVideoTransferFunctionKey] as? String ?? ""
    }

    var player: AVQueuePlayer?
    var playerItem: AVPlayerItem?
    var looper: AVPlayerLooper?

    private var timeObserver: Any?
    private var subscriptions: Set<AnyCancellable> = []
    var statusObserver: NSKeyValueObservation?
//    var videoOutput: AVPlayerItemVideoOutput?
    //    var displayLink: CADisplayLink?

    var displayLink: CADisplayLink?

    @MainActor
    deinit {
        self.cleanup()
        print("VideoModel deinit: \(self)")
    }

    func load(_ url: URL) async throws {
        // Stop accessing the old URL's security scoped resource if it exists
        if let oldURL = _url {
            print("Previously loaded URL not released properly!")
            oldURL.stopAccessingSecurityScopedResource()
        }

        // Start accessing the new URL's security scoped resource
        let success = url.startAccessingSecurityScopedResource()
        guard success else {
            // Handle failure to access security scoped resource
            throw VideoModelError.securityScopedResourceAccessFailed(url)
        }

        _url = url

        let resourceValue = try url.resourceValues(forKeys: [.contentTypeKey])
        utType = resourceValue.contentType

        if utType.conforms(to: .movie) || utType.conforms(to: .video) {
            // video resource
            print("Resource is video")
            isVideo = true
            asset = AVURLAsset(url: url)

            try await parseVideoMetadata(asset: asset!)
            // Recreate asset to avoid side-affects caused by parsing metadata
            asset = AVURLAsset(url: url)

            // Set up the player item and time observer when loading a new asset
            playerItem = AVPlayerItem(asset: asset!)
            player = AVQueuePlayerWithOutput(videoOutputSettings: videoOutputSettings)
            player!.actionAtItemEnd = .advance
            addObservers()
            // optimization mentioned in wwdc2016/503
            player!.play()
            looper = AVPlayerLooper(player: player!, templateItem: playerItem!)
            player!.replaceCurrentItem(with: playerItem)
        } else {
            isVideo = false
        }
    }

    func parseVideoMetadata(asset: AVAsset) async throws {
        let videoTracks = try await asset.loadTracks(withMediaCharacteristic: .visual)
        if videoTracks.isEmpty {
            print("No video track found in asset")
            return
        }

        let hdrTracks = try await asset.loadTracks(withMediaCharacteristic: .containsHDRVideo)
        isHDR = !hdrTracks.isEmpty

        let firstTrack = videoTracks.first!
        let size = try await firstTrack.load(.naturalSize)
        self.naturalSize = size
        print("Loaded natural size: \(size)")
        self.duration = try await asset.load(.duration).seconds
        print("Loaded duration: \(self.duration)")
        self.frameRate = try await firstTrack.load(.nominalFrameRate) as Float
        print("Loaded frame rate: \(self.frameRate)")

        self.assetPreferredTransform = try await firstTrack.load(.preferredTransform)

        videoColorProperties = [
            AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
            AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
            AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
        ]
        let formatDescriptions = try await firstTrack.load(.formatDescriptions)
        if let primaryFormatDescription = formatDescriptions.first {
            if let transferFunctionValue = primaryFormatDescription.extensions[.transferFunction] {
                print(
                    "Transfer function: \(transferFunctionValue) : plist: \(transferFunctionValue.propertyListRepresentation)"
                )
                let transferFunction = transferFunctionValue.propertyListRepresentation as! CFString
                if transferFunction
                    == CMFormatDescription.Extensions.Value.TransferFunction.itu_R_2020.rawValue
                {
                    // ITU_R_2020 requires special handling because there is no matching AVFoundation value for it.
                    // All of the other relevant transfer functions are spelled identically between CM and AV.
                    videoColorProperties[AVVideoTransferFunctionKey] =
                        AVVideoTransferFunction_ITU_R_709_2
                } else {
                    videoColorProperties[AVVideoTransferFunctionKey] = transferFunction as String
                }
                print(
                    "Selected output transfer function: \(String(describing: videoColorProperties[AVVideoTransferFunctionKey]))"
                )
            } else {
                print("No transfer function set, using ITU_R_709_2")
                videoColorProperties[AVVideoTransferFunctionKey] = AVVideoTransferFunction_ITU_R_709_2
            }
            if let videoColorPrimaries = primaryFormatDescription.extensions[.colorPrimaries] {
                print("Color primaries: \(videoColorPrimaries.propertyListRepresentation)")
                videoColorProperties[AVVideoColorPrimariesKey] =
                    videoColorPrimaries.propertyListRepresentation as! String
            } else {
                print("Cannot obtain color primaries, using default value: \(self.videoColorProperties[AVVideoColorPrimariesKey] ?? "none")")
            }
            if let videoYCbCrMatrix = primaryFormatDescription.extensions[.yCbCrMatrix] {
                print("YCbCrMatrix: \(videoYCbCrMatrix.propertyListRepresentation)")
                videoColorProperties[AVVideoYCbCrMatrixKey] =
                    videoYCbCrMatrix.propertyListRepresentation as! String
            } else {
                print("Cannot obtain YCbCrMatrix, using default value: \(self.videoColorProperties[AVVideoYCbCrMatrixKey] ?? "none")")
            }
            // Parse color range and bit depth
            isFullRange = primaryFormatDescription.extensions[.fullRangeVideo] == .number(1)
            if let bitsPerComponent = primaryFormatDescription.extensions[.bitsPerComponent] {
                if bitsPerComponent == .number(8) {
                    bitDepth = .bit8
                } else if bitsPerComponent == .number(10)  {
                    bitDepth = .bit10
                } else {
                    throw VideoModelError.unknownFormat("bitDepth: \(bitsPerComponent.propertyListRepresentation)")
                }
            } else {
                print("Cannot obtain bitDepth, using default value: \(self.bitDepth)")
            }
            print("Video isFullRange: \(isFullRange), bitDepth: \(bitDepth)")
            
            // Get color space information and determine
            let colorPrimaries = primaryFormatDescription.extensions[.colorPrimaries]?.propertyListRepresentation as? String
            let yCbCrMatrix = primaryFormatDescription.extensions[.yCbCrMatrix]?.propertyListRepresentation as? String
            
            // Determine color space standard
            self.colorSpace = VideoColorSpace.from(
                yCbCrMatrix: yCbCrMatrix, 
                colorPrimaries: colorPrimaries,
                videoSize: size
            )
            
            print("Color Primaries: \(colorPrimaries ?? "Not specified")")
            print("YCbCr Matrix: \(yCbCrMatrix ?? "Not specified")")
            print("Video Size: \(size)")
            print("Detected Color Space: \(self.colorSpace)")
            
            // Set video output properties based on color space
            switch self.colorSpace {
            case .bt601:
                // BT.601 color space - use available constants
                videoColorProperties[AVVideoYCbCrMatrixKey] = AVVideoYCbCrMatrix_ITU_R_601_4
                videoColorProperties[AVVideoColorPrimariesKey] = AVVideoColorPrimaries_SMPTE_C
                print("Using BT.601 color space (mapped to SMPTE_C for AVFoundation)")
            case .bt709:
                videoColorProperties[AVVideoYCbCrMatrixKey] = AVVideoYCbCrMatrix_ITU_R_709_2
                videoColorProperties[AVVideoColorPrimariesKey] = AVVideoColorPrimaries_ITU_R_709_2
                print("Using BT.709 color space")
            case .bt2020:
                videoColorProperties[AVVideoYCbCrMatrixKey] = AVVideoYCbCrMatrix_ITU_R_2020
                videoColorProperties[AVVideoColorPrimariesKey] = AVVideoColorPrimaries_ITU_R_2020
                print("Using BT.2020 color space")
            case .p3:
                videoColorProperties[AVVideoColorPrimariesKey] = AVVideoColorPrimaries_P3_D65
                print("Using P3 color space")
            default:
                print("Using default color space (BT.709)")
            }
        }
        if formatDescriptions.count > 1 {
            print("Not handling multiple video format descriptions")
        }

        var pixelFormatType = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        switch bitDepth {
        case .bit8:
            pixelFormatType =
                isFullRange
                ? kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
                : kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        case .bit10:
            pixelFormatType =
            isFullRange
            ? kCVPixelFormatType_420YpCbCr10BiPlanarFullRange
            : kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
        }

        print("Chose pixel format type: \(pixelFormatType.description)")

        videoOutputSettings = [
            // disable wide color support for vision os
//            AVVideoAllowWideColorKey: true,
            AVVideoColorPropertiesKey: videoColorProperties,
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferPixelFormatTypeKey as String: pixelFormatType,
            //            kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_64RGBAHalf),
            //            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8PlanarFullRange,
        ]
    }

    private func addObservers() {
        player!.publisher(for: \.timeControlStatus)
            .sink { [weak self] status in
                switch status {
                case .playing:
                    self?.isPlaying = true
                case .paused:
                    self?.isPlaying = false
                case .waitingToPlayAtSpecifiedRate:
                    break
                @unknown default:
                    break
                }
            }
            .store(in: &subscriptions)

        let interval = CMTime(value: 1, timescale: 10)
        self.timeObserver = self.player!.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            guard let self else {
                print("timeObserver invalidated, self is nil")
                return
            }
            Task { @MainActor in
                // Update the observable properties on the main actor
                if !self.isEditingCurrentTime {
                    self.currentTime = time.seconds
                }
            }
        }
    }

//    func prepareForRender() async throws {
//        guard let playerItem = self.playerItem else {
//            throw VideoModelError.initializationFailed("trying to setup video output before playerItem is set")
//        }
//        self.videoOutput = makeVideoOutput()
//        if self.videoOutput == nil{
//            throw VideoModelError.initializationFailed("video output has not been initialized")
//        }
//        playerItem.add(self.videoOutput!)
            //        #if os(visionOS)
            //        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkCopyPixelBuffers(link:)))
            //        #elseif os(macOS)
            //        displayLink = (NSApp.mainWindow?.displayLink(target: self, selector: #selector(displayLinkCopyPixelBuffers(link:))))!
            //        #endif

            //        self.statusObserver = playerItem.observe(\.status,
            //                                                  options: [.new, .old, .initial],
            //                                                  changeHandler: { [weak self] playerItem, change in
            //            Task { @MainActor in
            //                guard let self = self else { return }
            ////                guard let displayLink = self.displayLink else { return }
            //                if playerItem.status == .readyToPlay {
            //                    print("Set videoOutput: \(self.videoOutput?.debugDescription ?? "None")")
            //                    playerItem.add(self.videoOutput!)
            ////                    displayLink.add(to: .main, forMode: .common)
            //                }
            //            }
            //        })
//    }

    // Optional: Method to manually cleanup resources
    func cleanup() {
        print("\(self.debugDescription): Video cleanup called")

        // Pause the player
        player?.pause()
        displayLink?.invalidate()
        displayLink = nil

        // Clean up player item and its associated resources
        if let playerItem = player?.currentItem {
            // Remove video output from player item before niling it
            if let videoOutput = videoOutput {
                playerItem.remove(videoOutput)
            }
        }
            // Remove time observer
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }

            // Invalidate status observer
        if let statusObserver = statusObserver {
            statusObserver.invalidate()
            self.statusObserver = nil
        }
        looper = nil
        playerItem = nil
        player = nil

        // Stop accessing security scoped resource if it exists
        if let url = _url {
            url.stopAccessingSecurityScopedResource()
            self._url = nil
        }

        // Cancel asset loading
        if let asset = asset {
            asset.cancelLoading()
            self.asset = nil
        }

        utType = nil

        // Reset properties
        naturalSize = .zero
        currentTime = 0.0
        duration = 0.0
        isHDR = false
        isVideo = false
        isFullRange = false
        bitDepth = .bit8
        assetPreferredTransform = .identity
        videoColorProperties = [:]

        print("\(self.debugDescription): Video cleanup completed")
    }

    var debugDescription: String {
        return "VideoModel holding url: \(self.url?.absoluteString ?? "None")"
    }
}

enum VideoModelError: Error {
    case securityScopedResourceAccessFailed(URL)
    case initializationFailed(String)
    case unknownFormat(String)

    var localizedDescription: String {
        switch self {
        case .securityScopedResourceAccessFailed(let url):
            return "Failed to start accessing security scoped resource for: \(url)"
        case .initializationFailed(let desc):
            return "Failed to initialize VideoModel: \(desc)"
        case .unknownFormat(let desc):
            return "Failed to parse asset with unknown format: \(desc)"
        }
    }
}
