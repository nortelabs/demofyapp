import SwiftUI
import AVFoundation
import AVKit

// macOS preview view that fits the video inside a calibrated "screen" window,
// then overlays the device frame PNG above it.
struct VideoFramePreview: NSViewRepresentable {
    final class PreviewView: NSView {
        let containerLayer = CALayer()
        let videoContainerLayer = CALayer()
        let playerLayer = AVPlayerLayer()
        let overlayLayer = CALayer()
        let guidesLayer = CALayer()

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            layer = CALayer()
            layer?.backgroundColor = NSColor.clear.cgColor

            containerLayer.masksToBounds = false
            overlayLayer.masksToBounds = false
            guidesLayer.masksToBounds = false
            guidesLayer.backgroundColor = .none

            videoContainerLayer.masksToBounds = true
            videoContainerLayer.backgroundColor = .clear

            playerLayer.videoGravity = .resizeAspect
            playerLayer.backgroundColor = NSColor.clear.cgColor

            videoContainerLayer.addSublayer(playerLayer)
            layer?.addSublayer(videoContainerLayer)
            layer?.addSublayer(overlayLayer)
            layer?.addSublayer(guidesLayer)
        }

        required init?(coder: NSCoder) { fatalError() }
    }

    var player: AVPlayer?
    var overlayImage: NSImage?
    // Percent-based screen window 0..100
    var screen: ScreenRect
    // Extra zoom and offsets (offsets are -100..100 like the prototype)
    var scale: Double
    var offsetX: Double
    var offsetY: Double
    var videoFitMode: VideoFitMode

    func makeNSView(context: Context) -> PreviewView {
        let v = PreviewView(frame: .zero)
        v.playerLayer.player = player
        return v
    }
    
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: PreviewView, context: Context) -> CGSize {
        let width = proposal.width ?? 400
        let height = proposal.height ?? 300
        return CGSize(width: width, height: height)
    }

    func updateNSView(_ v: PreviewView, context: Context) {
        // Only update player if it has changed
        if v.playerLayer.player !== player {
            v.playerLayer.player = player
        }

        // Ensure the view has proper bounds - use the superview's bounds if available
        var bounds = v.bounds
        if bounds.width == 0 || bounds.height == 0 {
            if let superview = v.superview {
                bounds = superview.bounds
                v.frame = bounds
            } else {
                // Fallback to reasonable default
                bounds = CGRect(x: 0, y: 0, width: 400, height: 300)
                v.frame = bounds
            }
        }
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // Determine the rect where the device frame image is actually displayed
        // We aspect-fit the overlay image within the available bounds and use the
        // same fitted rect as the basis for positioning the video screen.
        var deviceDisplayRect = bounds
        if let img = overlayImage {
            let imageSize = img.size
            if imageSize.width > 0 && imageSize.height > 0 {
                let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
                let fittedW = imageSize.width * scale
                let fittedH = imageSize.height * scale
                let fittedX = bounds.origin.x + (bounds.width - fittedW) / 2.0
                let fittedY = bounds.origin.y + (bounds.height - fittedH) / 2.0
                deviceDisplayRect = CGRect(x: fittedX, y: fittedY, width: fittedW, height: fittedH)
            }
        }

        // Overlay (device frame) - ensure it's on top, aligned with fitted rect
        v.overlayLayer.frame = deviceDisplayRect
        v.overlayLayer.zPosition = 100 // Ensure overlay is on top
        
        if let img = overlayImage {
            // Convert NSImage to CGImage for CALayer
            if let cgImage = img.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                v.overlayLayer.contents = cgImage
                v.overlayLayer.contentsGravity = .resizeAspect
                v.overlayLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
                v.overlayLayer.isHidden = false
                v.overlayLayer.opacity = 1.0
                v.overlayLayer.backgroundColor = NSColor.clear.cgColor
            } else {
                v.overlayLayer.isHidden = true
            }
        } else {
            v.overlayLayer.isHidden = true
        }

        // Compute screen rect in pixels relative to the device display rect
        let sx = deviceDisplayRect.origin.x + CGFloat(screen.x / 100.0) * deviceDisplayRect.width
        let sy = deviceDisplayRect.origin.y + CGFloat(screen.y / 100.0) * deviceDisplayRect.height
        let sw = CGFloat(screen.w / 100.0) * deviceDisplayRect.width
        let sh = CGFloat(screen.h / 100.0) * deviceDisplayRect.height
        let screenRect = CGRect(x: sx, y: sy, width: sw, height: sh)

        v.videoContainerLayer.frame = screenRect
        v.videoContainerLayer.zPosition = 0

        switch videoFitMode {
        case .fit:
            v.playerLayer.videoGravity = .resizeAspect
        case .fill:
            v.playerLayer.videoGravity = .resizeAspectFill
        case .stretch:
            v.playerLayer.videoGravity = .resize
        }

        // Ensure the player layer fits exactly within the container bounds
        v.playerLayer.frame = v.videoContainerLayer.bounds
        v.playerLayer.masksToBounds = true

        if player != nil {
            v.playerLayer.isHidden = false
            v.playerLayer.opacity = 1.0
        } else {
            v.playerLayer.isHidden = true
        }

        let zoom = max(0.1, scale / 100.0)
        let dx = (offsetX / 100.0) * (v.playerLayer.bounds.width / 4.0)
        let dy = (offsetY / 100.0) * (v.playerLayer.bounds.height / 4.0)

        if zoom != 1.0 || dx != 0 || dy != 0 {
            v.playerLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            v.playerLayer.position = CGPoint(x: v.videoContainerLayer.bounds.midX, y: v.videoContainerLayer.bounds.midY)
            var t = CATransform3DIdentity
            t = CATransform3DTranslate(t, dx, -dy, 0)
            t = CATransform3DScale(t, zoom, zoom, 1)
            v.playerLayer.transform = t
        } else {
            v.playerLayer.transform = CATransform3DIdentity
        }

        // Ensure video is strictly clipped to the screen area
        v.videoContainerLayer.masksToBounds = true
        
        // Create a precise clipping mask for the screen area
        let cornerRadius = min(screenRect.width, screenRect.height) * 0.12
        v.videoContainerLayer.cornerRadius = cornerRadius
        
        // Create a more precise mask to ensure no bleeding
        let mask = CAShapeLayer()
        mask.frame = v.videoContainerLayer.bounds
        let maskPath = CGPath(roundedRect: v.videoContainerLayer.bounds, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        mask.path = maskPath
        mask.fillColor = NSColor.white.cgColor
        v.videoContainerLayer.mask = mask
        
        // Also set the player layer to mask its bounds
        v.playerLayer.masksToBounds = true

        v.guidesLayer.sublayers?.forEach { $0.removeFromSuperlayer() }

        CATransaction.commit()
    }
}

private extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [NSPoint](repeating: .zero, count: 3)
        for i in 0..<elementCount {
            let type = element(at: i, associatedPoints: &points)
            switch type {
            case .moveTo: path.move(to: points[0])
            case .lineTo: path.addLine(to: points[0])
            case .curveTo: path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .cubicCurveTo: path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .quadraticCurveTo: path.addQuadCurve(to: points[1], control: points[0])
            case .closePath: path.closeSubpath()
            @unknown default: break
            }
        }
        return path
    }
}