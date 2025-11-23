//
//  PlaneMesh.swift
//  MyMTLTestApp
//
//

import RealityKit
import Metal

struct PlaneMesh {
    var mesh: LowLevelMesh!
    let size: SIMD2<Float>
    
    /// The number of vertices in each dimension of the plane mesh.
    let dimensions: SIMD2<UInt32>
    
    let maxVertexDepth: Float
    
    init(size: SIMD2<Float>, dimensions: SIMD2<UInt32>, maxVertexDepth: Float = 1.0) throws {
        self.size = size
        self.dimensions = dimensions
        self.maxVertexDepth = maxVertexDepth
        
        self.mesh = try createMesh()
        initializeVertexData()
        initializeIndexData()
        initializeMeshParts()
    }
    
    private func vertexIndex(_ xCoord: UInt32, _ yCoord: UInt32) -> UInt32 {
        xCoord + dimensions.x * yCoord
    }
    
    private func createMesh() throws -> LowLevelMesh {
        // Define vertex attributes
        let positionAttrOffset = MemoryLayout.offset(of: \Vertex.position) ?? 0
        let normalAttrOffset = MemoryLayout.offset(of: \Vertex.normal) ?? 16
        let texCoordAttrOffset = MemoryLayout.offset(of: \Vertex.texCoord) ?? 32
        
        let positionAttr = LowLevelMesh.Attribute(
            semantic: .position,
            format: .float3,
            offset: positionAttrOffset
        )
        let normalAttr = LowLevelMesh.Attribute(
            semantic: .normal,
            format: .float3,
            offset: normalAttrOffset
        )
        let texCoordAttr = LowLevelMesh.Attribute(
            semantic: .uv0,
            format: .float2,
            offset: texCoordAttrOffset
        )

        let vertexAttributes = [positionAttr, normalAttr, texCoordAttr]
        
        let vertexLayouts = [LowLevelMesh.Layout(bufferIndex: 0, bufferStride: MemoryLayout<Vertex>.stride)]
        
        // Derive the vertex and index count from the dimensions
        let vertexCount = Int(dimensions.x * dimensions.y)
        let indicesPerTriangle = 3
        let trianglesPerCell = 2
        let cellCount = Int((dimensions.x - 1) * (dimensions.y - 1))
        let indexCount = indicesPerTriangle * trianglesPerCell * cellCount
        
        let meshDescriptor = LowLevelMesh.Descriptor(
            vertexCapacity: vertexCount,
            vertexAttributes: vertexAttributes,
            vertexLayouts: vertexLayouts,
            indexCapacity: indexCount
        )
        
        return try LowLevelMesh(descriptor: meshDescriptor)
    }
    
    private func initializeVertexData() {
        mesh.withUnsafeMutableBytes(bufferIndex: 0) { rawBytes in
            let vertices = rawBytes.bindMemory(to: Vertex.self)
            let normalDirection: SIMD3<Float> = [0, 0, 1]
            
            for xCoord in 0..<dimensions.x {
                for yCoord in 0..<dimensions.y {
                    // Remap coordinates to range [0, 1]
                    let x01 = Float(xCoord) / Float(dimensions.x - 1)
                    let y01 = Float(yCoord) / Float(dimensions.y - 1)
                    
                    // Calculate vertex position
                    // Origin is the plane's center
                    let xPos = size.x * x01 - size.x / 2
                    let yPos = size.y * y01 - size.y / 2
                    let zPos = Float(0)
                    
                    let vertexIndex = Int(vertexIndex(xCoord, yCoord))
                    vertices[vertexIndex].position = [xPos, yPos, zPos]
                    vertices[vertexIndex].normal = normalDirection
                    vertices[vertexIndex].texCoord = [xPos, yPos]
                }
            }
        }
    }
    
    /// Initializes the indices of the mesh two triangles at a time for each cell in the mesh.
    private func initializeIndexData() {
        mesh.withUnsafeMutableIndices() { rawIndices in
            guard var indices = rawIndices.baseAddress?.assumingMemoryBound(to: UInt32.self) else { return }
            
            for xCoord in 0..<dimensions.x - 1 {
                for yCoord in 0..<dimensions.y - 1 {
                    let bottomLeft  = vertexIndex(xCoord,     yCoord)
                    let bottomRight = vertexIndex(xCoord + 1, yCoord)
                    let topLeft     = vertexIndex(xCoord,     yCoord + 1)
                    let topRight    = vertexIndex(xCoord + 1, yCoord + 1)
                    
                    indices[0] = bottomLeft
                    indices[1] = bottomRight
                    indices[2] = topLeft
                    
                    indices[3] = topLeft
                    indices[4] = bottomRight
                    indices[5] = topRight
                    
                    indices += 6
                }
            }
        }
    }
    
    /// Initializes mesh parts, indicating topology and bounds.
    private func initializeMeshParts() {
        let bounds = BoundingBox(
            min: [-size.x / 2, -size.y / 2, 0],
            max: [size.x / 2, size.y / 2, maxVertexDepth]
        )
        
        mesh.parts.replaceAll([LowLevelMesh.Part(indexCount: mesh.descriptor.indexCapacity,
                                                 topology: .triangle,
                                                 bounds: bounds)])
    }
}
