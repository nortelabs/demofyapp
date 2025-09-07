import SwiftUI
import AVFoundation
import AVKit

// macOS preview view that fits the video inside a calibrated "screen" window,
// then overlays the device frame PNG above it.
struct VideoFramePreview: NSViewRepresentable {
    final class PreviewView: NSView {
        let containerLayer = CALayer()
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

            playerLayer.videoGravity = .resizeAspectFill
            playerLayer.backgroundColor = NSColor.clear.cgColor
            playerLayer.masksToBounds = true

            layer?.addSublayer(playerLayer) // we'll size/transform it inside screen window
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
    var showGuides: Bool

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

        // Overlay (device frame)
        v.overlayLayer.frame = bounds
        
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

        // Compute screen rect in pixels
        let sx = CGFloat(screen.x / 100.0) * bounds.width
        let sy = CGFloat(screen.y / 100.0) * bounds.height
        let sw = CGFloat(screen.w / 100.0) * bounds.width
        let sh = CGFloat(screen.h / 100.0) * bounds.height
        let screenRect = CGRect(x: sx, y: sy, width: sw, height: sh)

        // Set player layer to fill the screen rect
        v.playerLayer.frame = screenRect

        // Calculate zoom level (1.0 = fit, >1.0 = zoom in)
        let zoom = max(0.1, scale / 100.0)
        
        // Calculate offsets relative to screen size
        let dx = (offsetX / 100.0) * (screenRect.width / 2.0)
        let dy = (offsetY / 100.0) * (screenRect.height / 2.0)
        
        // Apply transform to position and scale the video within the screen rect
        // Center the video within the screen rect
        v.playerLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        v.playerLayer.position = CGPoint(x: screenRect.midX, y: screenRect.midY)
        
        // Use resizeAspectFill to ensure the video fills the screen area
        // This will crop the video if needed to maintain aspect ratio
        v.playerLayer.videoGravity = .resizeAspectFill
        v.playerLayer.masksToBounds = true
        
        // Ensure the layer is properly configured for video display
        v.playerLayer.backgroundColor = NSColor.clear.cgColor
        
        // Ensure the player layer is visible when there's a player
        if player != nil {
            v.playerLayer.isHidden = false
            v.playerLayer.opacity = 1.0
        } else {
            v.playerLayer.isHidden = true
        }
        
        // Apply transform for zoom and offset
        // For zoom: 1.0 = normal size, >1.0 = zoom in, <1.0 = zoom out
        var t = CATransform3DIdentity
        t = CATransform3DTranslate(t, dx, -dy, 0) // Invert dy to match coordinate system
        t = CATransform3DScale(t, zoom, zoom, 1) // Direct zoom scaling
        v.playerLayer.transform = t
        
        // Rounded corners for the screen
        v.playerLayer.cornerRadius = min(screenRect.width, screenRect.height) * 0.028

        // Guides
        v.guidesLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        if showGuides {
            let guide = CAShapeLayer()
            guide.frame = bounds
            let path = NSBezierPath(roundedRect: screenRect, xRadius: v.playerLayer.cornerRadius, yRadius: v.playerLayer.cornerRadius)
            guide.path = path.cgPath
            guide.fillColor = NSColor.clear.cgColor
            guide.strokeColor = NSColor.systemGreen.withAlphaComponent(0.9).cgColor
            guide.lineWidth = 2
            guide.lineDashPattern = [6, 4]
            v.guidesLayer.addSublayer(guide)
        }

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
