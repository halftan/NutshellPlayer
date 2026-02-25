//
//  OpenVRImageButton.swift
//  MyMTLTestApp
//
//

import SwiftUI
import UniformTypeIdentifiers
import os.log

struct OpenVRContentButton: View {
    private var logger = Logger(subsystem: "fun.NutshellPlayer", category: "OpenVRContentButton")

    @State private var showFileImporter = false

    @Environment(AppModel.self) private var appModel
    @Environment(Settings.self) private var settings
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    func doOpenImmersiveSpace() async {
        appModel.immersiveSpaceState = .inTransition
        switch await openImmersiveSpace(id: appModel.immersiveViewID) {
        case .opened:
            break

        case .userCancelled, .error:
            fallthrough
        @unknown default:
            appModel.immersiveSpaceState = .closed
        }
    }

    var body: some View {
        VStack {
            Button("Select file") {
                showFileImporter = true
            }
            .glassBackgroundEffect(in: .buttonBorder)

            Button {
                Task { @MainActor in
                    switch appModel.immersiveSpaceState {
                    case .open:
                        await appModel.videoModel.stop()
                        appModel.immersiveSpaceState = .inTransition
                        await dismissImmersiveSpace()
                    case .closed:
                        await doOpenImmersiveSpace()
                    case .inTransition:
                        // This case should not ever happen because button is disabled for this case.
                        break
                    }
                }
            } label: {
                Text(
                    appModel.immersiveSpaceState == .open
                        ? "Hide Immersive Space" : "Show Immersive Space"
                )
            }
            .disabled(appModel.immersiveSpaceState == .inTransition)
            .glassBackgroundEffect(in: .buttonBorder)
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.image, .video, .movie]
        ) { result in
            switch result {
            case .failure(let error):
                print(error.localizedDescription)
            case .success(let url):
                Task {
                    do {
                        try await appModel.videoModel.open(url)
                        appModel.videoModel.play()
                        await doOpenImmersiveSpace()
                    } catch {
                        logger.error("\(error)")
                    }
                }
            }
        }
    }
}
