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
        bundleImageName: "iphone-16-pro-black", // add iphone-16-pro-black.png to your bundle
        defaultScreen: .init(x: 7.2, y: 5.8, w: 85.6, h: 88.4)
    ),
    FramePreset(
        key: .iphone16plusBlack,
        label: "iPhone 16 Plus — Black",
        bundleImageName: "iphone-16-plus-black", // add iphone-16-plus-black.png
        defaultScreen: .init(x: 6.8, y: 5.6, w: 86.5, h: 89.0)
    ),
    FramePreset(
        key: .custom,
        label: "Custom (Upload PNG)",
        bundleImageName: nil,
        defaultScreen: .init(x: 7.2, y: 5.8, w: 85.6, h: 88.4)
    )
]

func formatTime(_ seconds: Double) -> String {
    guard seconds.isFinite else { return "0:00" }
    let s = max(0, Int(seconds.rounded()))
    let m = s / 60
    let r = s % 60
    return "\(m):" + String(format: "%02d", r)
}