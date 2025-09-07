# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
Demofy is a macOS SwiftUI application for creating demo-ready videos by recording iOS Simulator content and overlaying device frames. The app supports video trimming, positioning adjustments, and export to MP4/MOV formats.

## Architecture

### Main Components
- **DemofyApp.swift**: Main SwiftUI app entry point
- **ContentView.swift**: Primary UI with recording controls, preview, and export options
- **Models.swift**: Core data structures (`FramePreset`, `ScreenRect`, `ExportFormat`, etc.)
- **SimulatorAndFFmpeg.swift**: iOS Simulator recording via `xcrun simctl` and FFmpeg integration
- **AVFExporter.swift**: Video composition and export using AVFoundation
- **VideoFramePreview.swift**: Real-time preview component for video + frame overlay

### Key Data Flow
1. Record iOS Simulator using `xcrun simctl io recordVideo`
2. Import/load video into AVPlayer for preview
3. Apply device frame overlay with positioning controls
4. Export final composition using either AVFoundation or FFmpeg

### Frame Assets
- Device frame PNGs are stored in `/Frames/` directory
- Frame presets defined in `Models.swift` with screen positioning coordinates
- Supports custom frame uploads via PNG import

## Development Commands

### Build and Run
```bash
# Open in Xcode
open Demofy/Demofy.xcodeproj

# Build from command line
xcodebuild -project Demofy/Demofy.xcodeproj -scheme Demofy build

# Run tests
xcodebuild -project Demofy/Demofy.xcodeproj -scheme Demofy test
```

### Testing
- Uses Swift Testing framework (not XCTest)
- Test files: `DemofyTests/DemofyTests.swift`, `DemofyUITests/DemofyUITests.swift`
- Currently has placeholder tests that need implementation

## Dependencies and Requirements
- **macOS**: Native SwiftUI application
- **External Tools**: Requires `xcrun` (Xcode Command Line Tools) for iOS Simulator recording
- **Optional**: FFmpeg for advanced export options (alternative to AVFoundation export)
- **Frameworks**: SwiftUI, AVFoundation, AVKit, AppKit, UniformTypeIdentifiers

## Key Implementation Details

### Video Export Strategies
1. **AVFExporter**: Native AVFoundation-based composition with Core Animation layers
2. **FFmpegRunner**: Shell command execution for FFmpeg-based processing (advanced users)

### Simulator Recording
- Uses `xcrun simctl io recordVideo` to capture iOS Simulator content
- Handles process management with graceful interruption and cleanup
- Automatic file validation after recording completion

### Frame Positioning System
- Screen rectangles defined as percentages (0-100) of frame dimensions
- Supports zoom (scale), and X/Y offset adjustments within screen boundaries
- Real-time preview updates during adjustment

## File Organization
```
Demofy/
├── Demofy/               # Main app target
│   ├── *.swift          # Core implementation
│   └── Assets.xcassets/ # App icons and resources
├── DemofyTests/         # Unit tests
├── DemofyUITests/       # UI tests
Frames/                   # Device frame PNG assets
v0-demofy-design/        # Legacy/prototype files
```