//
//  ImmersiveVRView.swift
//  MyMTLTestApp
//
//

import RealityKit
import SwiftUI
import UniformTypeIdentifiers

struct ImmersiveVRView: View {

    @Environment(AppModel.self) private var appModel
    @Environment(Settings.self) private var settings
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    private var root = Entity()
    private var playerEntity = VRPlayerEntity()
    private var eventCatchingEntity = Entity()

    var body: some View {
        GeometryReader3D { proxy in
            RealityView { content in

                // Use fileModel's URL instead of hardcoded file
                guard
                    let resourceFileURL = appModel.videoModel.url
                else {
                    print("No file is selected!")
                    print("Failed to get texture file URL")
                    return
                }

                // let myMesh = try! PlaneMesh(size: [1.0, 1.0], dimensions: [16, 16])
                // let myMesh = try! HemisphereMesh(radius: 100, segments: 128, rings: 128, maxVertexDepth: 100)
                // let mesh = try! await MeshResource(from: myMesh.mesh)
                // let mat = try! await UnlitMaterial(texture: TextureResource(contentsOf: textureFile))
                // let m = ModelEntity(mesh: mesh, materials: [mat])

//                 root.components.set(InputTargetComponent())
//                 var collision = CollisionComponent(shapes: [.generate(radius: 100)])
//                 collision.filter = CollisionFilter(group: [], mask: [])
//                 root.components.set(collision)

                let anchor = AnchorEntity(.head, trackingMode: .once)
                let continuousTrackingAnchor = AnchorEntity(.head, trackingMode: .continuous)
                eventCatchingEntity.components.set(InputTargetComponent())
                eventCatchingEntity.components.set(CollisionComponent(shapes: [.generateBox(width: 100, height: 100, depth: 0.1)], isStatic: true))
                eventCatchingEntity.transform.translation.z = -10
                continuousTrackingAnchor.addChild(eventCatchingEntity)

                content.add(anchor)
                content.add(continuousTrackingAnchor)
                anchor.addChild(root)
                root.addChild(playerEntity)
                playerEntity.scale = .init(x: 1, y: 1, z: -1)
                await playerEntity.setup(
                    resourceFile: resourceFileURL,
                    provider: appModel.videoModel)

                appModel.videoModel.makeDisplayLink(target: playerEntity, selector: #selector(VRPlayerEntity.update))
            }
            update: { content in
                 root.transform.translation = .init(
                     x: settings.translateX,
                     y: settings.translateY,
                     z: settings.translateZ
                 )
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
                // Hide main window when immersive space appears
                if appModel.mainWindowState == .open {
                    print("Immersive space appeared - hiding main window")
                    dismissWindow(id: appModel.mainWindowID)
                }
            }
            .onDisappear {
                print("Disappeared")
                print("Cleaning up resources")
                appModel.videoModel.cleanup()
            }
            .gesture(
                SpatialTapGesture()
                    .targetedToEntity(eventCatchingEntity)
                    .onEnded { event in
                        print("Tap gesture received: \(event.gestureValue)")
                        Task {
                            switch appModel.mainWindowState {
                            case .closed:
                                print("Main window is closed, bringing it up now.")
                                appModel.mainWindowState = .inTransition
                                openWindow(id: appModel.mainWindowID)
                            case .inTransition:
                                // do nothing
                                print("Main window in transition, do nothing")
                                break
                            case .open:
                                print("Main window is open, closing it now.")
                                dismissWindow(id: appModel.mainWindowID)
                            }
                        }
                    }
            )
        }
    }
}
