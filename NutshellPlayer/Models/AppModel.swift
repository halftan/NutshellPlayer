//
//  AppModel.swift
//  MyMTLTestApp
//
//

import SwiftUI
import UniformTypeIdentifiers

@Observable
class AppModel {
    let mainWindowID = "main"
    let realityWindowID = "RealityWindow"
    let immersiveViewID = "ImmersiveVRPlayerView"
    let contentWindowID = "ContentWindow"

    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    var immersiveSpaceState = ImmersiveSpaceState.closed

    enum MainWindowState {
        case closed
        case inTransition
        case open
    }
    var mainWindowState = MainWindowState.open

    var videoModel: Playable = FFmpegVideo()
}
