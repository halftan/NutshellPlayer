//
//  PlaybackControlsView.swift
//  MyMTLTestApp
//
//

import SwiftUI
import AVFoundation

struct PlaybackControlsView: View {
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

    var body: some View {
        VStack {
            HStack(alignment: .center) {
                Button {
                    appModel.videoModel.pause()
                    Task {
                        await appModel.videoModel.stop()
                        await dismissImmersiveSpace()
                    }
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 20))
                        .tint(Color.primary)
                }
                .buttonStyle(.borderless)
                Button {
                    if appModel.videoModel.isPlaying {
                        appModel.videoModel.pause()
                    } else {
                        appModel.videoModel.play()
                    }
                } label: {
                    Image(systemName: appModel.videoModel.isPlaying ? "pause.fill" : "play.fill")
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
                        let result = await appModel.videoModel.seek(to: .init(seconds: currentTime, preferredTimescale: 2))
                        print("Seek result is: \(result)")
                        isVideoTransporting = false
                    }
                }
            })
            .frame(width: 280)
            .onChange(of: appModel.videoModel.currentTime, initial: true) { _, newVal in
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
            .onChange(of: appModel.videoModel.duration, initial: true) { _, newVal in
                duration = appModel.videoModel.duration
                durationTimeString = durationFormatter.string(from: duration) ?? "00:00"
            }
            .padding(.vertical)
        }
    }
}
