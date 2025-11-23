//
//  DepthStencilStates.swift
//  MyMTLTestApp
//
//

import Metal

struct DepthStencilStates {
    
    let device: MTLDevice
    
    init(device: MTLDevice) {
        self.device = device
    }
    
    func makeDepthStencilState(label: String, _ block: (MTLDepthStencilDescriptor) -> Void) -> MTLDepthStencilState {
        let descriptor = MTLDepthStencilDescriptor()
        block(descriptor)
        descriptor.label = label
        if let depthStencilState = device.makeDepthStencilState(descriptor: descriptor) {
            return depthStencilState
        } else {
            fatalError("Failed to create depth-stencil state with label \(label).")
        }
    }
}
