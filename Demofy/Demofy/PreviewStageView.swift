import SwiftUI
import AVFoundation

// Extracted to speed up SwiftUI type-checking in ContentView
struct PreviewStageView: View {
    // Inputs
    var use3DFrame: Bool
    var player: AVPlayer?
    var frameImage: NSImage?
    var screenRect: ScreenRect
    var scale: Double
    var offsetX: Double
    var offsetY: Double
    var showGuides: Bool
    var videoFitMode: VideoFitMode
    var stageAspectRatio: CGFloat
    var on3DMappingFailed: () -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if use3DFrame {
                    Device3DPreview(
                        player: player,
                        image: nil,
                        modelBaseName: "Frames/iphone_16_black_frame",
                        backgroundColor: .white,
                        allowsCameraControl: true,
                        debugLogHierarchy: false,
                        onMappingStatus: { ok in
                            if !ok { on3DMappingFailed() }
                        },
                        overlayScreenRect: screenRect
                    )
                    .frame(width: geo.size.width - 40, height: geo.size.height - 40)
                    .cornerRadius(12)
                    .shadow(color: Color.primaryBrand.opacity(0.2), radius: 12, x: 0, y: 6)
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                } else {
                    VideoFramePreview(
                        player: player,
                        overlayImage: frameImage,
                        screen: screenRect,
                        scale: scale,
                        offsetX: offsetX,
                        offsetY: offsetY,
                        showGuides: showGuides,
                        videoFitMode: videoFitMode
                    )
                    .frame(width: geo.size.width - 40, height: geo.size.height - 40)
                    .cornerRadius(12)
                    .shadow(color: Color.primaryBrand.opacity(0.2), radius: 12, x: 0, y: 6)
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                }

                // Empty state when nothing is loaded (2D mode only)
                if frameImage == nil && !use3DFrame && player == nil {
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(Color.primaryBrand)
                                .frame(width: 96, height: 96)
                                .subtleShadow()
                                .floating()
                            Circle()
                                .fill(.white.opacity(0.1))
                                .frame(width: 76, height: 76)
                            Image(systemName: "iphone.gen3")
                                .font(.system(size: 36, weight: .medium))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        }
                        VStack(spacing: 12) {
                            Text("Ready to Create")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primaryBrand)
                            Text("Select a device frame to get started")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.accentBrand.opacity(0.2))
                                    .frame(width: 24, height: 24)
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.accentBrand)
                            }
                            Text("Choose from Frame Preset menu")
                                .font(.callout)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(.thickMaterial)
                                .overlay(
                                    Capsule()
                                        .stroke(Color.accentBrand.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .subtleShadow()
                    }
                    .padding(32)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.thickMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.border, lineWidth: 1)
                            )
                    )
                    .shadow(color: Color.primaryBrand.opacity(0.2), radius: 20, x: 0, y: 8)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                }
            }
            .aspectRatio(stageAspectRatio, contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(20)
        }
    }
}


