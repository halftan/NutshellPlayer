import AVFoundation

typealias VideoOutputSettings = [String: any Sendable]

enum BitDepth: Int {
    case bit8 = 8
    case bit10 = 10
}

enum SteroeType: String, Identifiable, CaseIterable {
    case sbs, ou

    var id: Self { self }

    static var defaultType: Self = .sbs
}


protocol Playable: Observable {
    var isVideo: Bool { get }
    var isFullRange: Bool { get }
    var isHDR: Bool { get }
    var isGammaEncoded: Bool { get }
    var bitDepth: BitDepth { get }
    var stereoType: SteroeType { get }

    var naturalSize: CGSize { get }
    var aspectRatio: CGFloat { get }
    // var optimalPixelFormat: OSType { get }
    var videoOutput: AVPlayerItemVideoOutput? { get }
    var videoOutputSettings: VideoOutputSettings { get }

    func cleanup()

    // playback controls
    var currentTime: TimeInterval { get }
    var duration: TimeInterval { get }
    var isEditingCurrentTime: Bool { get set }
    var isPlaying: Bool { get }

    nonisolated func seek(to: CMTime) async -> Bool
    nonisolated func stop() async
    func pause()
    func play()

}
