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

enum VideoColorSpace {
    case bt601
    case bt709
    case bt2020
    case p3
    case sRGB
    case unknown
    
    static func from(yCbCrMatrix: String?, colorPrimaries: String?, videoSize: CGSize) -> VideoColorSpace {
        // Priority: Use YCbCr matrix for determination
        if let matrix = yCbCrMatrix {
            switch matrix {
            case "ITU_R_601_4":
                return .bt601
            case "ITU_R_709_2":
                return .bt709
            case "ITU_R_2020":
                return .bt2020
            default:
                break
            }
        }
        
        // If YCbCr matrix is not available, use color primaries for determination
        if let primaries = colorPrimaries {
            switch primaries {
            case "ITU_R_601_4":
                return .bt601
            case "ITU_R_709_2":
                return .bt709
            case "ITU_R_2020":
                return .bt2020
            case "P3_D65":
                return .p3
            case "SRGB":
                return .sRGB
            default:
                break
            }
        }
        
        // Key: When no metadata is available, default to BT.601
        if yCbCrMatrix == nil && colorPrimaries == nil {
            return .bt601
        }
        
        return .unknown
    }
}


protocol Playable: Observable {
    var url: URL? { get }
    var isVideo: Bool { get }
    var isFullRange: Bool { get }
    var isHDR: Bool { get }
    var bitDepth: BitDepth { get }
    var stereoType: SteroeType { get }
    var colorSpace: VideoColorSpace { get }

    var naturalSize: CGSize { get }
    var aspectRatio: CGFloat { get }
    // var optimalPixelFormat: OSType { get }
    var videoOutput: SampleBufferProvider? { get }
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

    func open(_ url: URL) async throws
}
