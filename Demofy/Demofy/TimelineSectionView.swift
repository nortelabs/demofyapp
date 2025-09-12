import SwiftUI
import AVFoundation

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        return path
    }
}

struct TimelineSectionView: View {
    var duration: Double
    @Binding var trimStart: Double
    @Binding var trimEnd: Double
    var isPlaying: Bool
    @Binding var isDarkMode: Bool // Add isDarkMode as a binding
    var togglePlayPause: () -> Void
    var seekToTime: (_ time: Double, _ pause: Bool) -> Void
    
    @State private var currentTime: Double = 0
    @State private var isDragging: Bool = false
    
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.orangeWeb)
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
                            .foregroundColor(isDarkMode ? .orangeWeb : .oxfordBlue) // Visible colors for both modes
                    }
                }
                .buttonStyle(.borderless)
                .help(isPlaying ? "Pause Video" : "Play Video")
                .disabled(duration <= 0)
                .opacity(duration <= 0 ? 0.5 : 1.0) // Reduce opacity when disabled
                .floating()
            }
            
            // iMovie-style timeline
            VStack(spacing: 12) {
                // Time indicators
                timeIndicators
                
                // Main timeline track
                timelineTrack
                
                // Time controls
                timeControls
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.border, lineWidth: 1)
                    )
            )
        }
        .onReceive(timer) { _ in
            if isPlaying && !isDragging {
                // Update currentTime based on actual playback
                // This is a simulation - in real app you'd get this from AVPlayer
                currentTime = min(duration, currentTime + 0.1)
            }
        }
    }
    
    private var timeIndicators: some View {
        HStack {
            Text(formatTimeCompact(0))
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(formatTimeCompact(duration))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var timelineTrack: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track (dark like iMovie)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(NSColor.textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.border, lineWidth: 1)
                    )
                    .frame(height: 80)
                
                // Video clips representation (thumbnails)
                videoClipsView(width: geometry.size.width)
                
                // Trim handles
                trimHandles(width: geometry.size.width)
                
                // Playhead
                playhead(width: geometry.size.width)
            }
            .onTapGesture { location in
                let progress = location.x / geometry.size.width
                let time = progress * duration
                currentTime = max(0, min(duration, time))
                seekToTime(currentTime, true)
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        let progress = max(0, min(1, value.location.x / geometry.size.width))
                        let time = progress * duration
                        currentTime = max(0, min(duration, time))
                        seekToTime(currentTime, false)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
        .frame(height: 80)
    }
    
    private func videoClipsView(width: CGFloat) -> some View {
        HStack(spacing: 1) {
            ForEach(0..<8, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.orangeWeb.opacity(0.2))
                    .overlay(
                        // iPhone mockup placeholder
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.oxfordBlue.opacity(0.8),
                                        Color.oxfordBlue,
                                        Color.oxfordBlue.opacity(0.8)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .overlay(
                                // iPhone shape silhouette
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.black.opacity(0.1))
                                    .frame(width: 20, height: 40)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.white.opacity(0.2))
                                            .frame(width: 16, height: 36)
                                    )
                            )
                    )
                    .frame(height: 76)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color.black.opacity(0.1), lineWidth: 0.5)
                    )
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
    }
    
    private func trimHandles(width: CGFloat) -> some View {
        HStack {
            // Start trim handle
            trimHandle(isStart: true, width: width)
            Spacer()
            // End trim handle
            trimHandle(isStart: false, width: width)
        }
    }
    
    private func trimHandle(isStart: Bool, width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.orangeWeb)
            .frame(width: 4, height: 80)
            .offset(x: isStart ? (trimStart / duration) * width : (trimEnd / duration) * width - width)
    }
    
    private func playhead(width: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Playhead handle (triangle)
            Triangle()
                .fill(Color.white)
                .frame(width: 12, height: 8)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            
            // Playhead line
            Rectangle()
                .fill(Color.white)
                .frame(width: 2, height: 80)
                .shadow(color: .black.opacity(0.3), radius: 1, x: 1, y: 0)
        }
        .offset(x: max(0, min(width - 12, (currentTime / max(0.1, duration)) * width - 6)))
        .animation(.linear(duration: isDragging ? 0 : 0.1), value: currentTime)
    }
    
    private var timeControls: some View {
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
    
    private func formatTimeCompact(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}


