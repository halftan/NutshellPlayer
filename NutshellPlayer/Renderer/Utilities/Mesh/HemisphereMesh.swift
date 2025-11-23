import RealityKit
import Metal

struct HemisphereMesh {
    var mesh: LowLevelMesh!
    let radius: Float
    let segments: UInt32
    let rings: UInt32
    
    /// The maximum depth of any vertex (used for bounding box)
    let maxVertexDepth: Float
    
    init(radius: Float, segments: UInt32, rings: UInt32, maxVertexDepth: Float = 1.0) throws {
        self.radius = radius
        self.segments = segments
        self.rings = rings
        self.maxVertexDepth = maxVertexDepth
        
        self.mesh = try createMesh()
        initializeVertexData()
        initializeIndexData()
        initializeMeshParts()
    }
    
    private func vertexIndex(_ segment: UInt32, _ ring: UInt32) -> UInt32 {
        segment + (segments + 1) * ring
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
        
        // Derive the vertex and index count
        let vertexCount = Int((segments + 1) * (rings + 1))
        let indicesPerTriangle = 3
        let trianglesPerCell = 2
        let cellCount = Int(segments * rings)
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
            
            for ring in 0...rings {
                for segment in 0...segments {
                    // Map ring and segment to spherical coordinates for hemisphere
                    // For VR 180, we want a hemisphere that spans 180 degrees horizontally
                    // and 180 degrees vertically (from bottom to top)
                    let u = Float(segment) / Float(segments)  // 0 to 1
                    let v = Float(ring) / Float(rings)        // 0 to 1
                    
                    // Convert to spherical coordinates for hemisphere
                    // Theta: horizontal angle (-π/2 to π/2 for 180° field of view)
                    // Phi: vertical angle (0 to π for 180° vertical coverage)
                    let theta = (u - 0.5) * .pi  // -π/2 to π/2
                    let phi = v * .pi            // 0 to π
                    
                    // Cartesian coordinates
                    let x = radius * sin(theta) * sin(phi)
                    let y = radius * cos(phi)
                    let z = radius * cos(theta) * sin(phi)
                    
                    let position: SIMD3<Float> = [x, y, z]

                    // Normal pointing inward (toward the viewer)
                    let normal = simd_normalize(position)
                    
                    // Equirectangular texture coordinates
                    // Map theta (-π/2 to π/2) to u (0 to 1)
                    // Map phi (0 to π) to v (0 to 1) - might need inversion depending on image
                    let texCoordU = u
                    let texCoordV = 1.0 - v  // Invert V coordinate for typical image orientation
                    
                    let texCoord: SIMD2<Float> = [texCoordU, texCoordV]
                    
                    let index = Int(vertexIndex(segment, ring))
                    vertices[index].position = position
                    vertices[index].normal = normal
                    vertices[index].texCoord = texCoord
                }
            }
        }
    }
    
    /// Initializes the indices of the mesh two triangles at a time for each cell.
    private func initializeIndexData() {
        mesh.withUnsafeMutableIndices() { rawIndices in
            guard var indices = rawIndices.baseAddress?.assumingMemoryBound(to: UInt32.self) else { return }
            
            for ring in 0..<rings {
                for segment in 0..<segments {
                    let bottomLeft  = vertexIndex(segment, ring)
                    let bottomRight = vertexIndex(segment + 1, ring)
                    let topLeft     = vertexIndex(segment, ring + 1)
                    let topRight    = vertexIndex(segment + 1, ring + 1)
                    
                    indices[0] = bottomLeft
                    indices[1] = topLeft
                    indices[2] = bottomRight
                    
                    indices[3] = topLeft
                    indices[4] = topRight
                    indices[5] = bottomRight
                    
                    indices += 6
                }
            }
        }
    }
    
    /// Initializes mesh parts, indicating topology and bounds.
    private func initializeMeshParts() {
        let bounds = BoundingBox(
            min: [-radius, -radius, -radius],
            max: [radius, radius, maxVertexDepth]
        )
        
        mesh.parts.replaceAll([LowLevelMesh.Part(indexCount: mesh.descriptor.indexCapacity,
                                                topology: .triangle,
                                                bounds: bounds)])
    }
}
