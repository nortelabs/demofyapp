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

enum FramePresetKey: String, CaseIterable, Identifiable {
    case iphone16proBlack
    case iphone16plusBlack
    case custom
    var id: String { rawValue }
}

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

let framePresets: [FramePreset] = [
    FramePreset(
        key: .iphone16proBlack,
        label: "iPhone 16 Pro — Black",
        bundleImageName: "Frames/iphone16problack",
        defaultScreen: .init(x: 8.5, y: 7.0, w: 83.0, h: 86.0)
    ),
    FramePreset(
        key: .iphone16plusBlack,
        label: "iPhone 16 Plus — Black",
        bundleImageName: "Frames/iphone16plusframeblack",
        defaultScreen: .init(x: 8.5, y: 7.0, w: 83.0, h: 86.0)
    ),
    FramePreset(
        key: .custom,
        label: "Custom (Upload PNG)",
        bundleImageName: nil,
        defaultScreen: .init(x: 8.5, y: 7.0, w: 83.0, h: 86.0)
    )
]

func formatTime(_ seconds: Double) -> String {
    guard seconds.isFinite else { return "0:00" }
    let s = max(0, Int(seconds.rounded()))
    let m = s / 60
    let r = s % 60
    return "\(m):" + String(format: "%02d", r)
}
