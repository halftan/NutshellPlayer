//
//  PipelineStates.swift
//  MyMTLTestApp
//
//

import Metal

struct PipelineStates {

    lazy var simpleTextureSampling = makeRenderPipelineState(label: "Texture Sampling") { descriptor in
        descriptor.vertexFunction = library.makeFunction(name: "vertex_fullscreen")
        descriptor.fragmentFunction = library.makeFunction(name: "fragment_linear_sbs")

        // TODO: add depth stencil to the scene
        descriptor.depthAttachmentPixelFormat = .invalid
        descriptor.stencilAttachmentPixelFormat = .invalid
        descriptor.colorAttachments[0]?.pixelFormat = colorPixelFormat
    }

    lazy var biPlanar8BitFullTextureSampling = makeYUVRenderPipelineStage(bitDepth: 8, isFullRange: true)
    lazy var biPlanar10BitFullTextureSampling = makeYUVRenderPipelineStage(bitDepth: 10, isFullRange: true)
    lazy var biPlanar8BitLimitedTextureSampling = makeYUVRenderPipelineStage(bitDepth: 8, isFullRange: false)
    lazy var biPlanar10BitLimitedTextureSampling = makeYUVRenderPipelineStage(bitDepth: 10, isFullRange: false)

    let device: MTLDevice
    let library: MTLLibrary

    let colorPixelFormat: MTLPixelFormat
    let depthStencilPixelFormat: MTLPixelFormat

    init(device: MTLDevice, renderDestination: RenderDestination) {
        self.device = device
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Failed to create Metal default library with device: \(device.description)")
        }
        self.library = library
        self.colorPixelFormat = renderDestination.colorPixelFormat
        self.depthStencilPixelFormat = renderDestination.depthStencilPixelFormat
    }

    func makeRenderPipelineState(label: String,
                                 block: (MTLRenderPipelineDescriptor) -> Void) -> MTLRenderPipelineState {
        let descriptor = MTLRenderPipelineDescriptor()
        block(descriptor)
        descriptor.label = label
        do {
            return try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    func makeYUVRenderPipelineStage(bitDepth: Int, isFullRange: Bool = false) -> MTLRenderPipelineState {
        makeRenderPipelineState(label: "BiPlanar \(bitDepth)bit \(isFullRange ? "Full" : "Limited") Range Texture Sampling") { descriptor in
            descriptor.vertexFunction = library.makeFunction(name: "vertex_fullscreen")
            descriptor.fragmentFunction = library.makeFunction(name: "fragment_\(bitDepth)bit_\(isFullRange ? "full" : "limited")_sbs")

            // TODO: add depth stencil to the scene
            descriptor.depthAttachmentPixelFormat = .invalid
            descriptor.stencilAttachmentPixelFormat = .invalid
            descriptor.colorAttachments[0]?.pixelFormat = colorPixelFormat
        }
    }
}
