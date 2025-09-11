import Foundation
import SwiftUI

struct ScreenRect: Codable, Equatable {
    var x: Double   // percent 0..100
    var y: Double   // percent 0..100
    var w: Double   // percent 0..100
    var h: Double   // percent 0..100
}

enum ExportFormat: String, CaseIterable, Identifiable {
    case mp4, mov
    var id: String { rawValue }
}

enum VideoFitMode: String, CaseIterable, Identifiable, Codable {
    case fit = "fit"        // Show entire video, may have letterboxing
    case fill = "fill"      // Fill screen, may crop video
    case stretch = "stretch" // Stretch to fill, may distort
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .fit: return "Fit"
        case .fill: return "Fill"
        case .stretch: return "Stretch"
        }
    }
    
    var description: String {
        switch self {
        case .fit: return "Show entire video"
        case .fill: return "Fill screen (may crop)"
        case .stretch: return "Stretch to fill (may distort)"
        }
    }
}

// Dynamic key for presets (use bundle path without extension, e.g. "Frames/iphone16problack").
// "custom" is reserved for user-supplied PNGs.
typealias FramePresetKey = String

struct FramePreset: Identifiable {
    let id = UUID()
    let key: FramePresetKey
    let label: String
    let bundleImageName: String?   // add this PNG to your app bundle; transparent screen area
    let defaultScreen: ScreenRect
}

enum RecordingState {
    case idle, recording, recorded
}

private func makeTitle(from fileStem: String) -> String {
    if fileStem.isEmpty { return "Untitled" }
    var s = fileStem
        .replacingOccurrences(of: "_", with: " ")
        .replacingOccurrences(of: "-", with: " ")
    // Insert space between letters and numbers
    var withSpaces: String = ""
    var prev: Character? = nil
    for ch in s {
        if let p = prev {
            if (p.isNumber && ch.isLetter) || (p.isLetter && ch.isNumber) {
                withSpaces.append(" ")
            }
        }
        withSpaces.append(ch)
        prev = ch
    }
    s = withSpaces
    return s.capitalized
}

private func loadFramePresetsFromBundle() -> [FramePreset] {
    var presets: [FramePreset] = []
    if let urls = Bundle.main.urls(forResourcesWithExtension: "png", subdirectory: "Frames") {
        for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let stem = url.deletingPathExtension().lastPathComponent
            let bundleName = "Frames/" + stem
            let title = makeTitle(from: stem)
            presets.append(
                FramePreset(
                    key: bundleName,
                    label: title,
                    bundleImageName: bundleName,
                    defaultScreen: .init(x: 6.5, y: 3.0, w: 87.0, h: 94.0)
                )
            )
        }
    }
    // Fallback to legacy defaults if none found
    if presets.isEmpty {
        presets = [
            FramePreset(
                key: "Frames/iphone16problack",
                label: "iPhone 16 Pro — Black",
                bundleImageName: "Frames/iphone16problack",
                defaultScreen: .init(x: 6.5, y: 3.0, w: 87.0, h: 94.0)
            ),
            FramePreset(
                key: "Frames/iphone16plusframeblack",
                label: "iPhone 16 Plus — Black",
                bundleImageName: "Frames/iphone16plusframeblack",
                defaultScreen: .init(x: 6.5, y: 3.0, w: 87.0, h: 94.0)
            )
        ]
    }
    // Always add Custom at end
    presets.append(
        FramePreset(
            key: "custom",
            label: "Custom (Upload PNG)",
            bundleImageName: nil,
            defaultScreen: .init(x: 6.5, y: 3.0, w: 87.0, h: 94.0)
        )
    )
    return presets
}

let framePresets: [FramePreset] = loadFramePresetsFromBundle()

func formatTime(_ seconds: Double) -> String {
    guard seconds.isFinite else { return "0:00" }
    let s = max(0, Int(seconds.rounded()))
    let m = s / 60
    let r = s % 60
    return "\(m):" + String(format: "%02d", r)
}
