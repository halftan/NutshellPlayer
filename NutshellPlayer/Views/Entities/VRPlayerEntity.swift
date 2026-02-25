//
//  VRPlayerEntity.swift
//  MyMTLTestApp
//
//
import SwiftUI
import AVFoundation
import CoreVideo
import RealityKit
import RealityKit_assets

struct RenderTarget {
    var colorTexture: LowLevelTexture!
    var depthStencilTexture: MTLTexture!
}

let frameBufferShader = LazyAsync {
    return try! await ShaderGraphMaterial(
        named: "/Root/Material",
        from: "FramebufferShader",
        in: realityKit_assetsBundle
    )
}

enum VRPlayerEntityError: Error {
    case initializationFailed(String)

    var localizedDescription: String {
        switch self {
        case .initializationFailed(let desc):
            return "Failed to initialize VRPlayerEntity: \(desc)"
        }
    }
}

@MainActor
func createFramebufferMaterial(leftEyeTexture: LowLevelTexture, rightEyeTexture: LowLevelTexture) async -> ShaderGraphMaterial {
    var material = await frameBufferShader.get()

    await MainActor.run {
        try! material.setParameter(name: "Eye_L", value: .textureResource(.init(from: leftEyeTexture)))
        try! material.setParameter(name: "Eye_R", value: .textureResource(.init(from: rightEyeTexture)))
    }

    return material
}

struct VRPlayerComponent: TransientComponent {}

class VRPlayerEntity: Entity, HasModel {
    var renderer: Renderer!

    var leftEyeTarget = RenderTarget()
    var rightEyeTarget = RenderTarget()
    var monoTarget: RenderTarget {
        leftEyeTarget
    }
    var monoMaterial: ShaderGraphMaterial!
    var stereoMaterial: ShaderGraphMaterial!

    var stereoOn = true

    // let textureSize = MTLSizeMake(1024, 1024, 1)
    // var aspectRatio: Double {
    //     Double(textureSize.width) / Double(textureSize.height)
    // }

    var device: MTLDevice!

    var colorPixelFormat: MTLPixelFormat = .rgba16Float
    var depthStencilPixelFormat: MTLPixelFormat = .depth32Float_stencil8

    // main frame texture, can also be used as luma for BiPlanar
    var texture: MTLTexture!
    var textureChroma: MTLTexture!

    var mediaProvider: Playable!
    var mtlTextureCache: CVMetalTextureCache?
    
    // The main Metal texture, can also be used as luma for BiPlanar
    var cvMetalTexture: CVMetalTexture!
    var cvMetalTextureChroma: CVMetalTexture!

    func makeRenderTarget(size: MTLSize) -> RenderTarget {
        let colorTexture = try! LowLevelTexture(descriptor: .init(textureType: .type2D,
                                                                  pixelFormat: colorPixelFormat,
                                                                  width: size.width,
                                                                  height: size.height,
                                                                  depth: size.depth,
                                                                  mipmapLevelCount: 1,
                                                                  textureUsage: [.shaderRead, .shaderWrite, .renderTarget]))

        let depthStencilDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: depthStencilPixelFormat,
                                                                              width: size.width,
                                                                              height: size.height,
                                                                              mipmapped: false)

        depthStencilDescriptor.storageMode = .memoryless
        depthStencilDescriptor.usage = [.renderTarget]

        let depthStencilTexture = device.makeTexture(descriptor: depthStencilDescriptor)

        return .init(colorTexture: colorTexture,
                     depthStencilTexture: depthStencilTexture)
    }

    private func makeMetalTextureCache() throws -> CVMetalTextureCache? {
        var mtlTextureCache: CVMetalTextureCache?
        let result = CVMetalTextureCacheCreate(kCFAllocatorDefault,
                                               nil,
                                               self.device,
                                               nil,
                                               &mtlTextureCache)
        switch result {
        case kCVReturnSuccess:
            print("Successfully created CVMetalTextureCache")
        case kCVReturnInvalidPixelFormat:
            throw VRPlayerEntityError.initializationFailed("Failed to create CVMetalTextureCache: invalid pixel format")
        default:
            throw VRPlayerEntityError.initializationFailed("Failed to create CVMetalTextureCache: CVReturn:\(result)")
        }

        return mtlTextureCache
    }

    @MainActor
    func setup(resourceFile: URL, provider: Playable) async {
        self.device = MTLCreateSystemDefaultDevice()

        var size: MTLSize
        mediaProvider = provider
        if mediaProvider.isVideo {
            print("Loading video resource")
            self.mtlTextureCache = try! makeMetalTextureCache()
            size = .init(
                width: Int(mediaProvider.naturalSize.width / 2), height: Int(mediaProvider.naturalSize.height), depth: 1
            )
            // make a default texture
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: colorPixelFormat,
                width: Int(mediaProvider.naturalSize.width / 2),
                height: Int(mediaProvider.naturalSize.height),
                mipmapped: false
            )
            self.texture = device.makeTexture(descriptor: descriptor)
        } else {
            print("Loading image resource")
            self.texture = try! await Renderer.loadTexture(device: device, resourceFile: resourceFile)
            size = .init(
                width: texture.width / 2,
                height: texture.height,
                depth: texture.depth
            )
        }

        self.leftEyeTarget = makeRenderTarget(size: size)
        self.rightEyeTarget = makeRenderTarget(size: size)

        self.monoMaterial = await createFramebufferMaterial(
            leftEyeTexture: leftEyeTarget.colorTexture,
            rightEyeTexture: leftEyeTarget.colorTexture
        )
        self.stereoMaterial = await createFramebufferMaterial(
            leftEyeTexture: leftEyeTarget.colorTexture,
            rightEyeTexture: rightEyeTarget.colorTexture
        )

//        let planeMesh = try! PlaneMesh(size: [0.1, 0.1], dimensions: [2, 2])
//        let mesh = try! await MeshResource(from: planeMesh.mesh)
//        let simpleMaterial = SimpleMaterial(color: .magenta, isMetallic: true)
//        let unlitMaterial = try! await UnlitMaterial(texture: TextureResource(contentsOf: Bundle.main.url(forResource: "uv1", withExtension: "png")!))
//        self.components.set(ModelComponent(mesh: mesh, materials: [simpleMaterial]))
//        self.components.set(ModelComponent(mesh: .generatePlane(width: 1.0, height: 1.0, cornerRadius: 0.1), materials: [unlitMaterial]))

        let hemisphereMesh = try! HemisphereMesh(radius: 10, segments: 128, rings: 256, maxVertexDepth: 1000)
        let hemisphereMeshResource = try! await MeshResource(from: hemisphereMesh.mesh)
        self.components.set(ModelComponent(mesh: hemisphereMeshResource, materials: [stereoMaterial]))

        self.components.set(VRPlayerComponent())

        createScene()
    }

    // var size: CGSize = .init(width: 100, height: 100)

    func createScene() {
        renderer = Renderer(device: device, renderDestination: self, textureProvider: self) { @MainActor [weak self] in
            guard let self else {
                return
            }

            if mediaProvider == nil || !mediaProvider!.isVideo {
                return
            }

            // Extract next frame if item is video
            // maybe useful?
            // CVMetalTextureCacheFlush(self.mtlTextureCache!, 0)

            guard let videoOutput = mediaProvider?.videoOutput else {
                print("video output not set!")
                return
            }
            guard let sampleBuffer = videoOutput.copyNextSampleBuffer() else {
                print("Failed to get next sample buffer from video output")
                return
            }
            sampleBuffer.withUnsafeSampleBuffer() { sbuf in
                guard let pixelBuffer = sbuf.imageBuffer else {
                    print("Got empty pixel buffer from sample buffer")
                    return
                }

                let lumaW = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
                let lumaH = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)

                var lumaTexture: CVMetalTexture?
                let resultLuma = CVMetalTextureCacheCreateTextureFromImage(
                    kCFAllocatorDefault,
                    self.mtlTextureCache!,
                    pixelBuffer,
                    nil,
                    self.mediaProvider.bitDepth == .bit10 ? .r16Unorm : .r8Unorm,
                    lumaW,
                    lumaH,
                    0,
                    &lumaTexture
                )
                switch resultLuma {
                case kCVReturnSuccess:
                    break
                default:
                    print("Error to fetch luma texture from plane 0: \(resultLuma)")
                    return
                }
                self.cvMetalTexture = lumaTexture
                self.texture = CVMetalTextureGetTexture(lumaTexture!)

                let chromaW = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1)
                let chromaH = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1)

                var chromaTexture: CVMetalTexture?
                let resultChroma = CVMetalTextureCacheCreateTextureFromImage(
                    kCFAllocatorDefault,
                    self.mtlTextureCache!,
                    pixelBuffer,
                    nil,
                    self.mediaProvider.bitDepth == .bit10 ? .rg16Unorm : .rg8Unorm,
                    chromaW,
                    chromaH,
                    1,
                    &chromaTexture
                )
                switch resultChroma {
                case kCVReturnSuccess:
                    break
                default:
                    print("Error to fetch chroma texture from plane 1: \(resultChroma)")
                    return
                }

                self.cvMetalTextureChroma = chromaTexture
                self.textureChroma = CVMetalTextureGetTexture(chromaTexture!)
            }


//            let pixelBufferWidth = CVPixelBufferGetWidth(pixelBuffer)
//            let pixelBufferHeight = CVPixelBufferGetHeight(pixelBuffer)
            
//            var cvTexture: CVMetalTexture?
//            let result = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
//                self.mtlTextureCache!,
//                pixelBuffer,
//                nil,
//                self.colorPixelFormat,
//                pixelBufferWidth,
//                pixelBufferHeight,
//                0,
//                &cvTexture)
            
        }
    }

    var paused = false

    @MainActor @objc
    func update() {
        if paused {
            texture = nil
            cvMetalTexture = nil
            return
        }
        autoreleasepool {
            let start = CACurrentMediaTime()
            renderer.draw(provider: self)
            let delta = CACurrentMediaTime() - start
            if delta > 0.011 {
                // frame took over 11ms, the frame budget for a smooth 90fps display
                print("Slow frame render time: \(delta)")
            }
        }
        guard let isVideo = mediaProvider?.isVideo else {
            // mediaProvider is nil, could be something wrong. Pause rendering
            paused = true
            return
        }
        if !isVideo {
            // image needs only 1 render pass
            paused = true
        }
    }

    // func setFrameSize(size: CGSize) {
    //     self.size = size
    //     renderer.drawableSizeWillChange(size: size)
    // }

    func setStereo(_ state: Bool) {
        if state == stereoOn {
            // same state, do nothing
            return
        }
        stereoOn = state
        if stereoOn {
            self.components[ModelComponent.self]?.materials = [stereoMaterial]
        } else {
            self.components[ModelComponent.self]?.materials = [monoMaterial]
        }
    }
}

extension VRPlayerEntity: DrawableProviding, RenderDestination {
    var viewCount: Int {
        return 2
    }

    func renderTarget(for viewIndex: Int) -> RenderTarget {
        switch viewIndex {
        case 0:
            return leftEyeTarget
        case 1:
            return rightEyeTarget
        default:
            return monoTarget
        }
    }

    func colorTexture(viewIndex: Int, for commandBuffer: any MTLCommandBuffer) -> (any MTLTexture)? {
        return renderTarget(for: viewIndex).colorTexture.replace(using: commandBuffer)
    }

    func depthStencilTexture(viewIndex: Int, for commandBuffer: any MTLCommandBuffer) -> (any MTLTexture)? {
        return renderTarget(for: viewIndex).depthStencilTexture
    }


}

class VRPlayerUpdaterSystem: System {
    required init(scene: RealityKit.Scene) {}

    static let vrplayer = EntityQuery(where: .has(VRPlayerComponent.self))

    func update(context: SceneUpdateContext) {
        for entity in context.entities(matching: Self.vrplayer, updatingSystemWhen: .rendering) {
            (entity as? VRPlayerEntity)?.update()
        }
    }
}
