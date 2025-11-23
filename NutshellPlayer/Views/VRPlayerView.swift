//
//  VRPlayerView.swift
//  MyMTLTestApp
//
//

import SwiftUI
import RealityKit

struct VRPlayerView: View {
    @State var root = Entity()
    @State var playerEntity = VRPlayerEntity()

    @State private var translateZ: Float = 0

    @Environment(AppModel.self) private var appModel

    var body: some View {
        GeometryReader3D { proxy in
            VStack {
                Slider(value: $translateZ, in: -2...2) {
                    Text("Translate Z")
                }
                .padding(.vertical)
                RealityView { content in
                    VRPlayerUpdaterSystem.registerSystem()

                    let resourceFile = Bundle.main.url(forResource: "uv1", withExtension: "png")!

                    content.add(root)
                    root.addChild(playerEntity)
                    await playerEntity.setup(resourceFile: resourceFile, provider: appModel.videoModel)
//                    await playerEntity.setup(resourceFile: resourceFile, frameSize: .init(width: proxy.size.width, height: proxy.size.height))
                        //                if let affineTransform = area.transform(in: .local) {
                        // //                    affineTransform.matrix4x4
                        //                    playerEntity.setTransformMatrix(.init(affineTransform), relativeTo: nil)
                        //                } else {
                        //                    print("Failed to get local area transform")
                        //                }
                        //                playerEntity.setTransformMatrix(area.transform(in: .global)?.matrix4x4)
                }
                update: { content in
    //                playerEntity.setFrameSize(size: .init(width: proxy.size.width, height: proxy.size.height))
    //                playerEntity.setTransformMatrix(.init(proxy.transform(in: .global)!), relativeTo: root)
                    let newFrame = content.convert(proxy.frame(in: .global), from: .global, to: .scene)
                    playerEntity.setScale([newFrame.extents.x, newFrame.extents.y, newFrame.extents.z], relativeTo: root)
                    root.transform.translation.z = translateZ
                }
                .onDisappear() {
                    print("Disappeared")
                }
                .realityViewLayoutBehavior(.centered)
                    //                     .onChange(of: proxy.size) { oldVal, newVal in
                    //                         playerEntity.setScale(
                    //                             [Float(newVal.width) / 200, Float(newVal.height) / 200, 1], relativeTo: root)
                    //                     }
                .frame(minWidth: 600, minHeight: 600)
            }
        }
    }
}
