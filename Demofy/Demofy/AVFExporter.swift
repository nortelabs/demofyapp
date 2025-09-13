import Foundation
import AVFoundation
import AppKit
import QuartzCore
import CoreImage

struct DemofyConfig: Codable {
    struct Canvas: Codable { let width: Int; let height: Int }
    struct Trim: Codable { let start: Double; let end: Double }
    struct Offset: Codable { let x: Double; let y: Double } // -1..1 of half-screen
    let outputFormat: String // "mp4" or "mov"
    let canvas: Canvas
    let trim: Trim
    let screenRect: ScreenRect // 0..100 percent
    let scale: Double          // 1.0 = fit, >1 zoom in
    let offset: Offset
    let videoFitMode: VideoFitMode
}

final class AVFExporter {
    enum ExportError: Error { case cannotLoadAsset, exportFailed }

    func export(
        inputURL: URL,
        frameImageURL: URL?,
        config: DemofyConfig,
        outputURL: URL
    ) async throws -> URL {
        let asset = AVURLAsset(url: inputURL)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw ExportError.cannotLoadAsset
        }

        let composition = AVMutableComposition()
        guard let compVideo = composition
            .addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw ExportError.cannotLoadAsset
        }

        // Trim
        let start = CMTime(seconds: config.trim.start, preferredTimescale: 600)
        let end = CMTime(seconds: config.trim.end, preferredTimescale: 600)
        let range = CMTimeRange(start: start, end: end)
        try compVideo.insertTimeRange(range, of: track, at: .zero)

        // Audio passthrough if available
        if let audioTrack = try await asset.loadTracks(withMediaType: .audio).first,
           let compAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            try compAudio.insertTimeRange(range, of: audioTrack, at: .zero)
        }

        // Render size
        let renderSize = CGSize(width: config.canvas.width, height: config.canvas.height)

        // Screen rect in output coordinates (convert 0..100 to 0..1 and multiply)
        let screen = CGRect(
            x: (config.screenRect.x / 100.0) * renderSize.width,
            y: (config.screenRect.y / 100.0) * renderSize.height,
            width: (config.screenRect.w / 100.0) * renderSize.width,
            height: (config.screenRect.h / 100.0) * renderSize.height
        )

        // Source natural size
        let (naturalSize, preferredTransform) = try await track.load(.naturalSize, .preferredTransform)
        let nat = naturalSize.applying(preferredTransform)
        let srcSize = CGSize(width: abs(nat.width), height: abs(nat.height))

        // Calculate base scale based on fit mode
        let baseScale: CGFloat
        switch config.videoFitMode {
        case .fit:
            // Fit entire video (object-fit: contain)
            baseScale = min(screen.width / srcSize.width, screen.height / srcSize.height)
        case .fill:
            // Fill screen (object-fit: cover)
            baseScale = max(screen.width / srcSize.width, screen.height / srcSize.height)
        case .stretch:
            // Stretch to fill (object-fit: fill)
            baseScale = 1.0 // Will be handled by separate width/height scaling
        }
        
        let extraScale = CGFloat(max(0.1, config.scale))
        let finalScale = baseScale * extraScale

        let scaledSize = CGSize(width: srcSize.width * finalScale, height: srcSize.height * finalScale)

        // Offsets in -1..1 of half-screen dimension
        let ox = CGFloat(config.offset.x) * (screen.width / 2.0)
        let oy = CGFloat(config.offset.y) * (screen.height / 2.0)

        // Position so video center aligns to screen center then offset
        // AVVideoComposition transform space acts like a bottom-left origin for
        // translation when combined with preferredTransform on macOS. Convert
        // our top-origin screen Y to that space.
        let tx = screen.midX - scaledSize.width / 2.0 + ox
        let ty = (renderSize.height - screen.midY) - scaledSize.height / 2.0 - oy

        // Build video composition instruction
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compVideo)
        var t = preferredTransform
        
        // Apply scaling based on fit mode
        if config.videoFitMode == .stretch {
            // For stretch mode, scale width and height independently to fill screen
            let scaleX = screen.width / srcSize.width
            let scaleY = screen.height / srcSize.height
            t = t.concatenating(CGAffineTransform(scaleX: scaleX, y: scaleY))
        } else {
            // For fit and fill modes, use uniform scaling
            t = t.concatenating(CGAffineTransform(scaleX: finalScale, y: finalScale))
        }
        
        t = t.concatenating(CGAffineTransform(translationX: tx, y: ty))
        layerInstruction.setTransform(t, at: .zero)
        // Rely on Core Animation mask for precise clipping to rounded screen area
        // Avoid extra cropping here to prevent coordinate-space mismatches that can
        // introduce unintended cutoffs at the edges.
        instruction.layerInstructions = [layerInstruction]

        let videoComposition = AVMutableVideoComposition()
        videoComposition.instructions = [instruction]
        videoComposition.renderSize = renderSize
        let nominalFrameRate = try await track.load(.nominalFrameRate)
        let fps = nominalFrameRate == 0 ? 30 : nominalFrameRate
        videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))

        // Core Animation overlay
        let parentLayer = CALayer()
        let videoLayer = CALayer()
        let overlayLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: renderSize)
        videoLayer.frame = parentLayer.bounds
        overlayLayer.frame = parentLayer.bounds
        // Keep default Core Animation coordinate system
        // Ensure the frame image preserves its aspect; the canvas is sized to match it
        overlayLayer.contentsGravity = .resizeAspect
        overlayLayer.masksToBounds = false

        if let imgURL = frameImageURL, let nsImage = NSImage(contentsOf: imgURL) {
            let trimmed = nsImage.trimmingTransparentPixels() ?? nsImage
            if let cg = trimmed.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                overlayLayer.contents = cg
            } else {
                overlayLayer.contents = trimmed
            }
            overlayLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0

            // Build an inverted-alpha mask from the frame image so video is visible
            // only where the frame is transparent (i.e., inside the device screen).
            if let cg = trimmed.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                let ciImage = CIImage(cgImage: cg)
                if let filter = CIFilter(name: "CIColorMatrix") {
                    filter.setValue(ciImage, forKey: kCIInputImageKey)
                    filter.setValue(CIVector(x: 0, y: 0, z: 0, w: -1), forKey: "inputAVector")
                    filter.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputBiasVector")
                    let context = CIContext(options: nil)
                    if let outImage = filter.outputImage,
                       let maskedCG = context.createCGImage(outImage, from: outImage.extent) {
                        let maskLayer = CALayer()
                        maskLayer.frame = parentLayer.bounds
                        maskLayer.contents = maskedCG
                        maskLayer.contentsGravity = .resizeAspect
                        maskLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
                        videoLayer.mask = maskLayer
                        videoLayer.masksToBounds = true
                    }
                }
            }
        }

        parentLayer.addSublayer(videoLayer)

        // Using the inverted-alpha image mask above; no additional shape mask needed here.

        parentLayer.addSublayer(overlayLayer)
        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )

        // Export
        try? FileManager.default.removeItem(at: outputURL)
        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw ExportError.exportFailed
        }
        session.outputURL = outputURL
        session.outputFileType = (config.outputFormat.lowercased() == "mov") ? .mov : .mp4
        session.videoComposition = videoComposition
        
        try await session.export(to: outputURL, as: session.outputFileType!)
        return outputURL
    }
}
