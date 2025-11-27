# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

- **Build for simulator**: `xcodebuild -scheme NutshellPlayer -destination 'platform=com.apple.platform.visionOS-simulator' build`
- **Build for device**: `xcodebuild -scheme NutshellPlayer -destination 'platform=com.apple.platform.visionOS' build`
- **Run tests**: `xcodebuild test -scheme NutshellPlayer -destination 'platform=com.apple.platform.visionOS-simulator'`
- **Open in Xcode**: Open `NutshellPlayer.xcodeproj` in Xcode 15+ with visionOS SDK

## Project Architecture

### High-Level Overview
**NutshellPlayer** is a visionOS VR video player for Apple Vision Pro that specializes in 180° stereoscopic content (Side-By-Side format) with advanced color space support and Metal rendering pipeline.

### Core Architecture Pattern
The application follows **MVVM with Protocol-Oriented Design**:

#### Models Layer (`@Observable`)
- **`AppModel`**: Central state management for window states and immersive space transitions
- **`VideoModel`**: Core media playback logic implementing `Playable` protocol, handles AVFoundation integration, metadata parsing, color space detection (BT.601/BT.709/BT.2020/P3), 8/10-bit video support, and resource cleanup
- **`Settings`**: User preferences and spatial translations

#### Views Layer (SwiftUI + RealityKit)
- **`NutshellPlayerApp`**: Multi-window architecture with main content, reality, and immersive space windows
- **`ImmersiveVRView`**: Primary VR interface using RealityKit with hemisphere mesh rendering, spatial gestures, and head tracking
- **`VRPlayerView`**: Alternative VR player interface
- **`ContentView`**: File selection and basic UI

#### Renderer Layer (Metal)
- **`Renderer`**: Metal command buffer management, YUV/RGB texture processing, multi-pipeline states for different color spaces
- **`VRPlayerEntity`**: RealityKit entity implementing `DrawableProviding` and `TextureProviding` protocols, integrates Metal rendering with spatial content
- **Custom shaders**: Located in RealityKit-assets package for tone mapping and color conversion

#### Protocols Layer
- **`Playable`**: Defines media playback interface (video properties, controls, texture access)
- **`TextureProviding`**: Metal texture access protocol
- **`DrawableProviding`**: Render target management protocol

### Key Technical Components

#### Multi-Window Architecture
- Main Window: File selection and playback controls
- Reality Window: Spatial interactions with RealityKit entities
- Immersive Space: Full VR playback environment with hemisphere mesh

#### Video Processing Pipeline
1. **Asset Loading**: AVURLAsset with security-scoped resource access
2. **Metadata Parsing**: Color space (YCbCr matrix, color primaries), bit depth, HDR detection, transfer functions
3. **Player Setup**: AVQueuePlayerWithOutput, AVPlayerItemVideoOutput configuration with proper color properties
4. **Texture Extraction**: Real-time pixel buffer extraction via CADisplayLink
5. **Metal Rendering**: Custom shaders for color space conversion and stereoscopic mapping

#### Color Space Management
- **BT.601**: Legacy SD video color space (recently added to fix banding)
- **BT.709**: Standard HD video color space
- **BT.2020**: UHD/HDR color space
- **P3**: Display P3 wide color gamut
- Automatic detection from video metadata with fallback to BT.601 for legacy content

#### Stereoscopic Formats
- **Side-By-Side (SBS)**: Current implementation for 180° VR content
- **Over-Under (OU)**: Planned support (enum defined but not implemented)
- **Mono/Stereo toggle**: User-selectable display modes in Settings

### Dependencies & Requirements
- **visionOS SDK**: Minimum v26, requires Xcode 15+
- **RealityKit-assets**: Custom package with Metal shaders and materials
- **Frameworks**: SwiftUI, RealityKit, AVFoundation, Metal, CoreVideo
- **Target Platforms**: visionOS (device and simulator)

### Development Guidelines

#### Code Organization
- **Protocol-first design**: Use `Playable`, `TextureProviding`, `DrawableProviding` protocols
- **Observable pattern**: Use `@Observable` for state management classes
- **Metal integration**: Keep Metal rendering code in dedicated Renderer classes
- **Async/await**: Use for media loading and metadata parsing
- **Resource cleanup**: Implement proper cleanup methods with security-scoped resource management

#### Video Format Support
- **Current**: VR 180° SBS (Side-By-Side) video and images, AVFoundation-supported codecs
- **Bit depths**: 8-bit and 10-bit with full/limited range detection
- **Pixel formats**: YUV bi-planar formats for Metal compatibility
- **Color spaces**: Automatic detection and proper handling

#### Memory Management
- Use `weak var` for delegate patterns and display link targets
- Implement `cleanup()` methods for proper resource deallocation
- Handle security-scoped resources with `start/stopAccessingSecurityScopedResource()`
- Proper observer invalidation on deinit

### Key File Locations
- **Main app**: `NutshellPlayerApp.swift`
- **Models**: `Models/AppModel.swift`, `Models/VideoModel.swift`
- **Views**: `Views/ImmersiveVRView.swift`, `Views/VRPlayerView.swift`
- **Renderer**: `Renderer/Renderer.swift`
- **Protocols**: `Protocols/Playable.swift`
- **RealityKit integration**: `Views/Entities/VRPlayerEntity+TextureProviding.swift`

### Platform-Specific Notes
- **ImmersiveSpace**: Configured for mixed immersion style in Info.plist
- **Spatial interactions**: Hand tracking and gaze input via RealityKit
- **Multi-window**: Leverages visionOS multiple scene capabilities
- **Metal compatibility**: Optimized for visionOS GPU architecture

### Planned Features (Roadmap)
- Over-Under (OU) stereoscopic format support
- Full 360° video playback
- mpvkit integration for broader codec/container support
- Advanced Metal shaders for tone mapping
- Streaming and DRM support