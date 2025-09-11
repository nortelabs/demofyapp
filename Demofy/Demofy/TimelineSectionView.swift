import SwiftUI

struct TimelineSectionView: View {
    var duration: Double
    @Binding var trimStart: Double
    @Binding var trimEnd: Double
    var isPlaying: Bool
    var togglePlayPause: () -> Void
    var seekToTime: (_ time: Double, _ pause: Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.secondaryBrand)
                        .frame(width: 32, height: 32)
                        .subtleShadow()
                    Image(systemName: "timeline.selection")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.brandBlack)
                }
                Text("Timeline")
                    .modernSectionHeader()
                Spacer()
                Button { togglePlayPause() } label: {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Circle()
                                    .stroke(Color.primaryBrand.opacity(0.3), lineWidth: 1)
                            )
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primaryBrand)
                    }
                }
                .buttonStyle(.borderless)
                .help(isPlaying ? "Pause Video" : "Play Video")
                .disabled(duration <= 0)
                .floating()
            }

            VStack(alignment: .leading, spacing: 16) {
                SliderWithValue(
                    "Start Time",
                    value: $trimStart,
                    in: 0...max(1, duration - 0.1),
                    step: 1,
                    format: "%.0f",
                    unit: "s"
                ) { isEditing in
                    trimStart = min(trimStart, trimEnd)
                    seekToTime(trimStart, true)
                }

                SliderWithValue(
                    "End Time",
                    value: $trimEnd,
                    in: 0...max(1, duration),
                    step: 1,
                    format: "%.0f",
                    unit: "s"
                ) { isEditing in
                    trimEnd = max(trimEnd, trimStart)
                    seekToTime(trimEnd, true)
                }

                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Duration")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatTime(max(0, trimEnd - trimStart)))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.accent)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.ultraThinMaterial)
                    )

                    Spacer()

                    VStack(alignment: .trailing, spacing: 6) {
                        Text("Total")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatTime(duration))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.ultraThinMaterial)
                    )
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                    )
            )
        }
    }
}


