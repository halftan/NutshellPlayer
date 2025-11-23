//
//  PlaybackControlsView.swift
//  MyMTLTestApp
//
//

import SwiftUI
import AVFoundation

struct PlaybackControlsView: View {
    private var media: Playable
    
    @Environment(AppModel.self) private var appModel
    @Environment(Settings.self) private var settings
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    
    @State private var currentTimeString: String = "00:00"
    @State private var durationTimeString: String = "00:00"
    @State private var currentTime: TimeInterval = .zero
    @State private var duration: TimeInterval = .zero

    @State private var isEditingState: Bool = false
    @State private var isVideoTransporting: Bool = false
    
    private let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()

    init(media: Playable) {
        self.media = media
    }
    
    var body: some View {
        VStack {
            HStack(alignment: .center) {
                Button {
                    media.pause()
                    Task {
                        await media.stop()
                        await dismissImmersiveSpace()
                    }
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 20))
                        .tint(Color.primary)
                }
                .buttonStyle(.borderless)
                Button {
                    if media.isPlaying {
                        media.pause()
                    } else {
                        media.play()
                    }
                } label: {
                    Image(systemName: media.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20))
                        .tint(Color.primary)
                }
                .buttonStyle(.borderless)
                
                HStack {
                    Text(currentTimeString)
                        .monospacedDigit()
                    Text("/")
                        .monospaced()
                    Text(durationTimeString)
                        .monospacedDigit()
                }
                .frame(minWidth: 150)
            }
            .padding()
            
            Slider(value: $currentTime, in: 0...duration, onEditingChanged: { isEditing in
                isEditingState = isEditing
                if isEditing == false {
                    isVideoTransporting = true
                    Task {
                        print("Seek to \(currentTime)")
                        let result = await media.seek(to: .init(seconds: currentTime, preferredTimescale: 2))
                        print("Seek result is: \(result)")
                        isVideoTransporting = false
                    }
                }
            })
            .frame(width: 280)
            .onChange(of: media.currentTime, initial: true) { _, newVal in
                if !(isEditingState || isVideoTransporting) {
                    currentTime = newVal
                    currentTimeString = durationFormatter.string(from: currentTime) ?? "00:00"
                }
            }
            .onChange(of: currentTime) { _, newVal in
                if isEditingState {
                    currentTime = newVal
                    currentTimeString = durationFormatter.string(from: currentTime) ?? "00:00"
                }
            }
            .onChange(of: media.duration, initial: true) { _, newVal in
                duration = media.duration
                durationTimeString = durationFormatter.string(from: duration) ?? "00:00"
            }
            .padding(.vertical)
        }
    }
}
