import Metal

extension VRPlayerEntity: TextureProviding {
    
    var bitDepth: BitDepth {
        get { mediaProvider.bitDepth }
    }
    
    var isFullRange: Bool {
        get { mediaProvider.isFullRange }
    }

    var isVideo: Bool {
        get { mediaProvider.isVideo }
    }
    var stereoType: SteroeType {
        get { mediaProvider.stereoType }
    }
    
    var colorSpace: VideoColorSpace {
        get { mediaProvider.colorSpace }
    }

    func frameTexture() -> (any MTLTexture)? {
        return texture
    }

    func frameTextureLuma() -> (any MTLTexture)? {
        return texture
    }

    func frameTextureChroma() -> (any MTLTexture)? {
        return textureChroma
    }
}

