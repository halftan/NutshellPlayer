//
//  NutshellPlayerApp.swift
//  NutshellPlayer
//
//

import SwiftUI

@main
struct NutshellPlayerApp: App {
    @State private var appModel = AppModel()
    @State private var settings = Settings()

    var body: some Scene {
        WindowGroup(id: appModel.mainWindowID) {
            ContentView()
                .environment(appModel)
                .environment(settings)

            SettingsView()
                .environment(appModel)
                .environment(settings)
                .padding(.bottom, 10)
        }
        .windowResizability(.contentSize)

        /// Reality window that plays 3D content on a plane
//        WindowGroup(id: appModel.realityWindowID) {
//            VRPlayerView()
//                .ignoresSafeArea()
//        }
//        .defaultSize(width: 1.0, height: 1.0, depth: 1.0, in: .meters)
//        .windowStyle(.plain)

        ImmersiveSpace(id: appModel.immersiveViewID) {
            ImmersiveVRView()
                .onAppear {
                    appModel.immersiveSpaceState = .open
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                }
                .environment(appModel)
                .environment(settings)
        }
        .immersionStyle(selection: .constant(.full), in: .mixed, .full)
        .upperLimbVisibility(settings.showHandsInImmersiveView)
    }
}
