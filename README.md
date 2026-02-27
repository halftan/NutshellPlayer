# NutshellPlayer

A simple VR video player for Apple Vision Pro — Swift-first with a small Metal rendering pipeline for immersive playback.

## Summary
- Purpose: Play VR 180 (Left/Right — Side‑By‑Side) videos and images on visionOS (Apple Vision Pro).
- Languages: Swift, Metal

## Current status
- Supports VR 180 Left/Right (SBS/LR) format for H.264 and HEVC videos in mp4
container. As long as supported by the Preview app, NutshellPlayer can play it.
- Supports static VR180 images, jpeg and png.
- Codec/container support comes from ffmpeg, but not widely tested.
NutshellPlayer uses [my own fork of SwiftFFmpeg](https://github.com/halftan/SFmpeg).

## Requirements
- Xcode 26+
- visionOS 26+

## Installation
1. git clone https://github.com/halftan/NutshellPlayer.git
2. Open NutshellPlayer.xcodeproj in Xcode.
3. Signing with your own team or personal account in **Signing & Capabilities**
   tab of project config.
4. Select your actual Vision Pro \(not simulator\) as target.
5. Run the project \(Cmd + R\).

## License
- GPL 3.0

## Implementation

The implementation uses **ShaderGraph** to create a custom material that can
display different textures for left and right eye \(aka stereoscopic image\).

Basic idea comes from [Apple demo project: Rendering a Windowed Game in
Stereo](https://developer.apple.com/documentation/RealityKit/rendering-a-windowed-game-in-stereo)

[Warren Moore's great presentation](https://www.youtube.com/watch?v=vO0M4c9mb2E) and [blog posts](https://metalbyexample.com/hdr-video/)
helped a lot in helping me understanding Metal.

