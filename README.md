# NutshellPlayer

A simple VR video player for Apple Vision Pro — Swift-first with a small Metal rendering pipeline for immersive playback.

Summary
- Purpose: Play VR 180 (Left/Right — Side‑By‑Side) videos and images on visionOS (Apple Vision Pro).
- Languages: Swift, Metal
- Repository owner: halftan (they/them)

Table of contents
- Current status
- Features
- Requirements
- Installation
- Build & run
- Usage
- Supported formats (current vs planned)
- TODO / Roadmap
- Contributing
- AI notice
- License & credits
- Contact

Current status
- Supports VR 180 Left/Right (SBS/LR) format for video and images only.
- 2D flat playback mode available.
- Minimal Metal renderer maps frames for VR presentation.
- Codec/container support is limited to what AVFoundation provides on the target device.

Features
- VR 180 (SBS LR) playback for video and still images on visionOS.
- Toggle between flat and VR mapping for 180 content.
- Lightweight Metal shaders for frame mapping and basic post-processing.
- Simple visionOS UI optimized for gaze/hand interactions.

Requirements
- macOS with Xcode that includes the visionOS SDK (use latest stable Xcode supporting visionOS).
- Xcode 15+ typically required for early visionOS SDKs.
- Vision Pro hardware is recommended for full testing; visionOS Simulator supported.

Installation
1. git clone https://github.com/halftan/NutshellPlayer.git
2. Open NutshellPlayer.xcodeproj or NutshellPlayer.xcworkspace in Xcode.

Build & run
- Select target: Vision Pro Device or visionOS Simulator.
- Set a signing team to run on device.
- Run (Cmd+R).

Command-line examples:
- Simulator:
  xcodebuild -scheme NutshellPlayer -destination 'platform=com.apple.platform.visionOS-simulator' build
- Device:
  xcodebuild -scheme NutshellPlayer -destination 'platform=com.apple.platform.visionOS' build

Usage
- Launch app on device or simulator.
- Load bundled demo content or open SBS video/image files via the app UI (Files picker, if available).
- Controls:
  - Gaze + hand tap to show/hide HUD.
  - Play/Pause, Seek, Mode toggle.
- Use Side‑By‑Side (LR) test files for correct left/right mapping.

Supported formats
- Current:
  - VR 180 LR (Side‑By‑Side) video and images only.
  - Codec/container support depends on AVFoundation (use H.264/HEVC where possible).
- Planned:
  - OU (Over/Under) stereoscopic formats.
  - Plain 3D stereoscopic video support.
  - Wider codecs/containers (MKV) via mpvkit integration.

TODO / Roadmap
High-priority
- Add OU (Over/Under) stereoscopic support.
- Add plain 3D stereoscopic and full 360 support.
- Integrate mpvkit to support:
  - Additional containers (e.g., MKV)
  - More codecs and subtitle tracks
  - Multiple audio track selection

Medium-priority
- Add sample test assets (SBS/OU).
- Format auto-detection and enhanced playback UI (audio/subtitle selection).
- Automated tests for rendering and playback.

Low-priority
- Advanced Metal shaders (tone mapping, color grading, foveated rendering).
- Streaming (adaptive bitrate) and DRM support.
- Performance profiling and optimizations for Vision Pro.

Contributing
- Fork, create a feature branch, implement changes, and open a PR with clear description and repro steps.
- Include test assets and tests when adding format support.
- For mpvkit proposals, include design notes on integrating its surface into the Metal renderer.

AI notice
- Some code and parts of this README were generated or assisted by AI tools. Please review generated code and text for correctness, security, and licensing.

License & credits
- See LICENSE in the repository for license terms. If absent, consider adding a license (MIT is a common choice).
- Thanks to visionOS, AVFoundation, Metal, and community resources.

Contact
- Owner: halftan (they/them)
- Report issues or request features via GitHub Issues.
