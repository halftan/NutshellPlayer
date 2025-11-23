//
//  VideoModel+MediaProvider.swift
//  MyMTLTestApp
//
//

import AVFoundation

extension VideoModel: Playable {
    var videoOutput: AVPlayerItemVideoOutput? {
        get {
            let output = self.player?.currentItem?.outputs.first as? AVPlayerItemVideoOutput
            return output
        }
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
