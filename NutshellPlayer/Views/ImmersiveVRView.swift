//
//  ImmersiveVRView.swift
//  MyMTLTestApp
//
//

import RealityKit
import SwiftUI
import UniformTypeIdentifiers
import os.log

struct ImmersiveVRView: View {
    private let logger = Logger(subsystem: "fun.NutshellPlayer", category: "ImmersiveVRView")

    @Environment(AppModel.self) private var appModel
    @Environment(Settings.self) private var settings
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var showPlaybackControls = false

    private var root = Entity()
    private var playerEntity = APMPPlayerEntity()
    private var eventCatchingEntity = Entity()
    private var anchor = AnchorEntity(.head, trackingMode: .once)
    private var continuousTrackingAnchor = AnchorEntity(.head, trackingMode: .continuous)

    var body: some View {
        GeometryReader3D { proxy in
            RealityView { content, attachments in

                eventCatchingEntity.components.set(InputTargetComponent())
                eventCatchingEntity.components.set(CollisionComponent(shapes: [.generateBox(width: 100, height: 100, depth: 0.1)], isStatic: true))
                eventCatchingEntity.transform.translation.z = -10

                content.add(root)
                root.addChild(anchor)
                root.addChild(continuousTrackingAnchor)
                continuousTrackingAnchor.addChild(eventCatchingEntity)
                anchor.addChild(playerEntity)
                playerEntity.scale = .init(x: 1, y: 1, z: -1)

//                let ball = ModelEntity(mesh: .generateSphere(radius: 1.0), materials: [SimpleMaterial(color: .red, isMetallic: false)])
//                ball.position = [0, 0, -8]
//                eventCatchingEntity.addChild(ball)

                if let playbackControlEntity = attachments.entity(for: "playback-control") {
                    playbackControlEntity.name = "playback-control"
                    playbackControlEntity.position = [0, -0.3, -1.5]
                    root.addChild(playbackControlEntity)
                }

                guard
                    let resourceFileURL = appModel.videoModel.url
                else {
                    print("No file is selected!")
                    print("Failed to get texture file URL")
                    return
                }

//                 let myMesh = try! PlaneMesh(size: [1.0, 1.0], dimensions: [16, 16])
//                 let myMesh = try! HemisphereMesh(radius: 100, segments: 128, rings: 128, maxVertexDepth: 100)
//                 let mesh = try! await MeshResource(from: myMesh.mesh)
//                 let mat = try! await UnlitMaterial(texture: TextureResource(contentsOf: textureFile))
//                 let m = ModelEntity(mesh: mesh, materials: [mat])

//                 root.components.set(InputTargetComponent())
//                 var collision = CollisionComponent(shapes: [.generate(radius: 100)])
//                 collision.filter = CollisionFilter(group: [], mask: [])
//                 root.components.set(collision)
//                await playerEntity.setup(
//                    resourceFile: resourceFileURL,
//                    provider: appModel.videoModel)
//                logger.info("Finished player entity setup")

//                if let videoModelNeedsDisplayLink = appModel.videoModel as? VideoModel {
//                    videoModelNeedsDisplayLink.makeDisplayLink(target: playerEntity, selector: #selector(VRPlayerEntity.update))
//                }

            } update: { content, attachments in
                 root.transform.translation = .init(
                     x: settings.translateX,
                     y: settings.translateY,
                     z: settings.translateZ
                 )
            } attachments: {
                Attachment(id: "playback-control") {
                    if showPlaybackControls {
                        VStack {
                            Text(appModel.videoModel.url?.lastPathComponent ?? "No file selected")
                                .font(.title)
                                .padding()
                                .background(.ultraThinMaterial)
                                .glassBackgroundEffect()
                            PlaybackControlsView()
                                .background(.ultraThinMaterial)
                                .glassBackgroundEffect()
                                .environment(appModel)
                        }
                    }
                }
            }
            .onChange(of: settings.stereoOn, initial: true) {
                playerEntity.setStereo(settings.stereoOn)
            }
            .onChange(of: appModel.videoModel.isPlaying, initial: true) {
                if appModel.videoModel.isVideo {
                    playerEntity.paused = !appModel.videoModel.isPlaying
                }
            }
            .onAppear {
                Task.immediate {
                    await playerEntity.setup(
                        provider: appModel.videoModel
                    )
                }
                // Hide main window when immersive space appears
                if appModel.mainWindowState == .open {
                    logger.info("Immersive space appeared - hiding main window")
                    dismissWindow(id: appModel.mainWindowID)
                }
            }
            .onDisappear {
                logger.info("Immersive view disappearing. Cleaning player entity")
                playerEntity.cleanup()
                openWindow(id: appModel.mainWindowID)
            }
            .gesture(
                SpatialTapGesture()
                    .targetedToEntity(eventCatchingEntity)
                    .onEnded { event in
                        if let playbackControlEntity = root.findEntity(named: "playback-control") {
                            if !showPlaybackControls {
//                                     reset playback control position
                                let newPos = continuousTrackingAnchor.convert(position: [0, -0.3, -1.6], to: root)
                                playbackControlEntity.setPosition(newPos, relativeTo: root)
                                playbackControlEntity.setOrientation(continuousTrackingAnchor.orientation(relativeTo: root), relativeTo: root)
                            }
                            showPlaybackControls.toggle()
                        }
                    }
            )
        }
    }
}
