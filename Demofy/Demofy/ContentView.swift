import SwiftUI
import AVFoundation
import AVKit
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    // State
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var recordingState: RecordingState = .idle
    @State private var simulatorDevice: String = "booted"
    @State private var recordingURL: URL?
    @State private var videoURL: URL?
    @State private var player: AVPlayer?

    @State private var framePreset: FramePresetKey = .iphone16plusBlack
    @State private var frameImageURL: URL?
    @State private var frameImage: NSImage?
    @State private var screenRect: ScreenRect = framePresets.first(where: { $0.key == .iphone16plusBlack })?.defaultScreen ?? framePresets.first!.defaultScreen
    @State private var showGuides: Bool = false
    @State private var use3DFrame: Bool = false

    @State private var scale: Double = 100 // percent - 100% for proper fitting
    @State private var offsetX: Double = 0 // -100..100
    @State private var offsetY: Double = 0 // -100..100
    @State private var videoFitMode: VideoFitMode = .fill

    @State private var duration: Double = 0
    @State private var trimStart: Double = 0
    @State private var trimEnd: Double = 0
    @State private var isPlaying: Bool = false

    @State private var outputFormat: ExportFormat = .mp4
    @State private var canvas: CGSize = CGSize(width: 1080, height: 1920)
    @State private var exporting = false
    @State private var exportProgressText = ""

    private let recorder = SimulatorRecorder()
    private let exporter = AVFExporter()

    var body: some View {
        HStack(spacing: 24) {
            VStack(spacing: 20) {
                // Preview Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(Color.primaryBrand)
                                .frame(width: 32, height: 32)
                                .subtleShadow()
                            
                            Image(systemName: "play.rectangle.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        Text("Preview")
                            .modernSectionHeader()
                        Spacer()
                        
                        Button {
                            isDarkMode.toggle()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primaryBrand.opacity(0.3), lineWidth: 1)
                                    )
                                
                                Image(systemName: isDarkMode ? "sun.max.fill" : "moon.fill")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primaryBrand)
                            }
                        }
                        .buttonStyle(.borderless)
                        .help(isDarkMode ? "Switch to Light Mode" : "Switch to Dark Mode")
                        .floating()
                    }
                    
                    ZStack {
                        // Modern glass background
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(NSColor.white))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.primaryBrand.opacity(0.3), lineWidth: 2)
                            )
                            .shadow(color: Color.primaryBrand.opacity(0.1), radius: 20, x: 0, y: 8)
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        
                        GeometryReader { geo in
                            let aspect = stageAspectRatio
                            ZStack {
                                if use3DFrame {
                                    Device3DPreview(
                                        player: player,
                                        image: nil,
                                        modelBaseName: "Frames/iphone_16_black_frame",
                                        backgroundColor: .white,
                                        allowsCameraControl: true
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
                                
                                // Enhanced empty state
                                if frameImage == nil && !use3DFrame {
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
                                                    .stroke(
                                                        Color.border,
                                                        lineWidth: 1
                                                    )
                                            )
                                    )
                                    .shadow(color: Color.primaryBrand.opacity(0.2), radius: 20, x: 0, y: 8)
                                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                                }
                            }
                            .aspectRatio(aspect, contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            .padding(20)
                        }
                    }
                    .frame(minHeight: 450)
                }

                // Timeline Section
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
                        
                        Button {
                            togglePlayPause()
                        } label: {
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
                        .disabled(player == nil)
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
                            if isEditing {
                                // Live scrubbing - seek while dragging
                                seekToTime(trimStart, pause: true)
                            } else {
                                // Final seek when done
                                seekToTime(trimStart, pause: true)
                            }
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
                            if isEditing {
                                // Live scrubbing - seek while dragging
                                seekToTime(trimEnd, pause: true)
                            } else {
                                // Final seek when done
                                seekToTime(trimEnd, pause: true)
                            }
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
            .frame(minWidth: 580)

            // Right controls
            ScrollView {
                VStack(spacing: 20) {
                    // Recording Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "record.circle.fill")
                                .font(.title2)
                                .foregroundColor(.accent)
                            Text("Record iOS Simulator")
                                .font(.title2)
                                .fontWeight(.bold)
                            Spacer()
                        }
                        
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                StatusIndicator(state: recordingState)
                                Spacer()
                            }
                            
                            LabeledControl("Device ID") {
                                TextField("booted", text: $simulatorDevice)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(.body, design: .monospaced))
                            }
                            
                            HStack(spacing: 12) {
                                if recordingState != .recording {
                                    Button {
                                        let url = askSaveURL(suggested: "demofy-recording.mp4")
                                        guard let url else { return }
                                        do {
                                            try recorder.startRecording(saveTo: url, device: simulatorDevice)
                                            recordingURL = url
                                            recordingState = .recording
                                        } catch { print("simctl start error:", error) }
                                    } label: {
                                        Label("Start Recording", systemImage: "record.circle.fill")
                                    }
                                    .modernButton(.primary, size: .medium)
                                } else {
                                    Button {
                                        recorder.stopRecording()
                                        recordingState = .recorded
                                    } label: {
                                        Label("Stop Recording", systemImage: "stop.fill")
                                    }
                                    .modernButton(.destructive, size: .medium)
                                }
                                
                                Button("Reset") {
                                    recorder.stopRecording()
                                    recordingURL = nil
                                    recordingState = .idle
                                }
                                .modernButton(.ghost, size: .medium)
                            }
                            
                            if let path = recordingURL?.path {
                                VStack(alignment: .leading, spacing: 12) {
                                    Divider()
                                        .background(Color(NSColor.separatorColor))
                                    
                                    HStack {
                                        Image(systemName: "folder.fill")
                                            .foregroundColor(.accent)
                                        Text(path)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                    }
                                    
                                    Button("Import to Timeline") {
                                        if let url = recordingURL {
                                            videoURL = url
                                            Task { await loadVideo(from: url) }
                                        }
                                    }
                                    .modernButton(.secondary, size: .small)
                                }
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

                    // Source & Frame Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.title2)
                                .foregroundColor(.accent)
                            Text("Source & Frame")
                                .font(.title2)
                                .fontWeight(.bold)
                            Spacer()
                        }
                        
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 12) {
                                Button {
                                    if let url = askOpenURL(allowed: [.movie]) {
                                        Task { await loadVideo(from: url) }
                                    }
                                } label: { 
                                    Label("Import Video", systemImage: "square.and.arrow.down") 
                                }
                                .modernButton(.secondary, size: .medium)

                                Button {
                                    if let url = askOpenURL(allowed: [.png]) {
                                        frameImageURL = url
                                        frameImage = NSImage(contentsOf: url)?.trimmingTransparentPixels()
                                        framePreset = .custom
                                        Task { await updateStageAspect() }
                                    }
                                } label: { 
                                    Label("Custom Frame", systemImage: "photo") 
                                }
                                .modernButton(.secondary, size: .medium)
                            }

                            LabeledControl("3D Mode") {
                                Toggle(isOn: $use3DFrame) {
                                    Text("Use 3D iPhone model (USDZ)")
                                }
                                .toggleStyle(.switch)
                            }
                            
                            LabeledControl("Device Frame") {
                                Picker("Frame Preset", selection: $framePreset) {
                                    ForEach(framePresets) { p in
                                        Text(p.label).tag(p.key)
                                    }
                                }
                                .pickerStyle(.menu)
                                .overlay(
                                    // Add pulsing highlight when no frame is selected
                                    frameImage == nil ? 
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.blue, lineWidth: 3)
                                        .scaleEffect(frameImage == nil ? 1.05 : 1.0)
                                        .opacity(frameImage == nil ? 0.8 : 0.0)
                                        .animation(
                                            frameImage == nil ? 
                                            Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true) : 
                                            .default, 
                                            value: frameImage == nil
                                        )
                                    : nil
                                )
                                .onChange(of: framePreset) { _, new in
                                    let p = framePresets.first { $0.key == new }!
                                    screenRect = p.defaultScreen
                                    if let name = p.bundleImageName {
                                        // Try with the Frames/ prefix first
                                        if let url = Bundle.main.url(forResource: name, withExtension: "png") {
                                            frameImageURL = url
                                            frameImage = NSImage(contentsOf: url)?.trimmingTransparentPixels()
                                            Task { await updateStageAspect() }
                                        } else {
                                            // Try without the Frames/ prefix
                                            let nameWithoutPrefix = name.replacingOccurrences(of: "Frames/", with: "")
                                            if let url = Bundle.main.url(forResource: nameWithoutPrefix, withExtension: "png") {
                                                frameImageURL = url
                                                frameImage = NSImage(contentsOf: url)?.trimmingTransparentPixels()
                                                Task { await updateStageAspect() }
                                            }
                                        }
                                    } else if new == .custom {
                                        // keep current custom image
                                    }
                                }
                                .disabled(use3DFrame)
                            }
                            
                            LabeledControl("Video Controls") {
                                HStack(spacing: 8) {
                                    Button("Fit to Frame") {
                                        Task { await autoFitVideo() }
                                    }
                                    .modernButton(.secondary, size: .small)
                                    .disabled(videoURL == nil)
                                    
                                    Button("Reset") {
                                        scale = 100
                                        offsetX = 0
                                        offsetY = 0
                                    }
                                    .modernButton(.ghost, size: .small)
                                    .disabled(videoURL == nil)
                                }
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

                    // Export Settings Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.title2)
                                .foregroundColor(.accent)
                            Text("Export Settings")
                                .font(.title2)
                                .fontWeight(.bold)
                            Spacer()
                        }
                        
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 16) {
                                LabeledControl("Format") {
                                    Picker("", selection: $outputFormat) {
                                        ForEach(ExportFormat.allCases) { fmt in 
                                            Text(fmt.rawValue.uppercased()).tag(fmt) 
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                }
                                
                                Spacer()
                                
                                LabeledControl("Resolution") {
                                    HStack(spacing: 8) {
                                        TextField("Width", value: $canvas.widthInt, formatter: NumberFormatter())
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: 80)
                                        Text("×")
                                            .foregroundColor(.secondary)
                                        TextField("Height", value: $canvas.heightInt, formatter: NumberFormatter())
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: 80)
                                    }
                                }
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                Button {
                                    Task { await exportWithAVFoundation() }
                                } label: { 
                                    HStack {
                                        if exporting {
                                            ProgressView()
                                                .controlSize(.small)
                                        } else {
                                            Image(systemName: "arrow.down.doc.fill")
                                        }
                                        Text(exporting ? "Exporting..." : "Export Video")
                                    }
                                }
                                .modernButton(.primary, size: .large)
                                .disabled(videoURL == nil || exporting)
                                .frame(maxWidth: .infinity)
                                
                            }
                            
                            if !exportProgressText.isEmpty {
                                HStack {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(.accent)
                                    Text(exportProgressText)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
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
                .padding(.vertical, 8)
            }
            .frame(width: 420)
        }
        .padding(24)
        .background(Color.background.ignoresSafeArea())
        .onAppear {
            // Don't load any frame by default - show popup instead
        }
        .onDisappear {
            player?.pause()
            isPlaying = false
            // Remove notification observers
            NotificationCenter.default.removeObserver(self)
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }

    // MARK: - Helpers

    @State private var stageAspectRatio: CGFloat = 9/19.5

    private func updateStageAspect() async {
        if let img = frameImage {
            stageAspectRatio = img.size.width / img.size.height
            return
        }
        if let player, let asset = player.currentItem?.asset {
            do {
                guard let track = try await asset.loadTracks(withMediaType: .video).first else {
                    stageAspectRatio = 9/19.5
                    return
                }
                let (naturalSize, transform) = try await track.load(.naturalSize, .preferredTransform)
                let sz = naturalSize.applying(transform)
                if sz.height > 0 {
                    stageAspectRatio = abs(sz.width / sz.height)
                } else {
                    stageAspectRatio = 9/19.5
                }
            } catch {
                print("Could not load video properties for aspect ratio: \(error)")
                stageAspectRatio = 9/19.5
            }
        } else {
            stageAspectRatio = 9/19.5
        }
    }

    private func loadVideo(from url: URL?) async {
    guard let url else { return }
    
    guard FileManager.default.fileExists(atPath: url.path) else {
        print("Video file does not exist at path: \(url.path)")
        return
    }
    guard FileManager.default.isReadableFile(atPath: url.path) else {
        print("Video file is not readable at path: \(url.path)")
        return
    }
    
    videoURL = url
    let asset = AVURLAsset(url: url)
    
    do {
        let isPlayable = try await asset.load(.isPlayable)
        guard isPlayable else {
            print("Video asset is not playable")
            return
        }
        
        let hasVideoTracks = try await asset.loadTracks(withMediaType: .video)
        guard !hasVideoTracks.isEmpty else {
            print("Video asset has no video tracks")
            return
        }
        
        let newDuration = try await asset.load(.duration).seconds
        duration = newDuration.isFinite ? newDuration : 0
        trimStart = 0
        trimEnd = duration
        
        // ✅ Orientation-corrected AVPlayerItem
        let item: AVPlayerItem
        do {
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            if let videoTrack = videoTracks.first {
                let transform = try await videoTrack.load(.preferredTransform)
                let naturalSize = try await videoTrack.load(.naturalSize)
                let correctedSize = naturalSize.applying(transform)
                let renderSize = CGSize(width: abs(correctedSize.width), height: abs(correctedSize.height))
                
                let instruction = AVMutableVideoCompositionInstruction()
                instruction.timeRange = CMTimeRange(start: .zero, duration: try await asset.load(.duration))
                
                let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
                layerInstruction.setTransform(transform, at: .zero)
                instruction.layerInstructions = [layerInstruction]
                
                let videoComposition = AVMutableVideoComposition()
                videoComposition.instructions = [instruction]
                videoComposition.renderSize = renderSize
                videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
                
                item = AVPlayerItem(asset: asset)
                item.videoComposition = videoComposition
            } else {
                item = AVPlayerItem(asset: asset)
            }
        } catch {
            print("Warning: couldn't build oriented videoComposition — falling back to raw item:", error)
            item = AVPlayerItem(asset: asset)
        }
        
        player = AVPlayer(playerItem: item)
        
        // Observers
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { notification in
            if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                print("Player failed: \(error.localizedDescription)")
            }
        }
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemNewErrorLogEntry,
            object: item,
            queue: .main
        ) { notification in
            if let errorLog = notification.object as? AVPlayerItemErrorLog {
                print("Player error log: \(errorLog)")
            }
        }
        
        player?.play()
        isPlaying = true
        
        addPlaybackObservers(to: item)
        
        await autoFitVideo()
        Task { await updateStageAspect() }
        
        DispatchQueue.main.async {
            self.videoFitMode = self.videoFitMode
        }
    } catch {
        print("Failed to load video: \(error.localizedDescription)")
        print("Error details: \(error)")
    }
}

    
    private func autoFitVideo() async {
        // Reset to default fitting - the video layer will handle the fitting automatically
        // based on the videoGravity setting in VideoFramePreview
        scale = 100.0
        offsetX = 0
        offsetY = 0
    }

    private func askOpenURL(allowed: [UTType]) -> URL? {
        let p = NSOpenPanel()
        p.allowedContentTypes = allowed
        p.allowsMultipleSelection = false
        p.canChooseDirectories = false
        return p.runModal() == .OK ? p.url : nil
    }

    private func askSaveURL(suggested: String) -> URL? {
        let p = NSSavePanel()
        p.nameFieldStringValue = suggested
        return p.runModal() == .OK ? p.url : nil
    }

    private func exportWithAVFoundation() async {
        guard let input = videoURL else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "demofy-output.\(outputFormat.rawValue)"
        guard panel.runModal() == .OK, let out = panel.url else { return }
        
        let cfg = DemofyConfig(
            outputFormat: outputFormat.rawValue,
            canvas: .init(width: Int(canvas.width), height: Int(canvas.height)),
            trim: .init(start: trimStart, end: trimEnd),
            screenRect: screenRect,
            scale: scale / 100.0,
            offset: .init(x: offsetX / 100.0, y: offsetY / 100.0),
            videoFitMode: videoFitMode
        )
        var frameURL: URL?
        if let u = frameImageURL {
            frameURL = u
        } else if let preset = framePresets.first(where: { $0.key == framePreset }),
                  let name = preset.bundleImageName,
                  let bURL = Bundle.main.url(forResource: name, withExtension: "png") {
            frameURL = bURL
        }

        exporting = true
        exportProgressText = "Exporting…"
        do {
            let resultURL = try await exporter.export(inputURL: input, frameImageURL: frameURL, config: cfg, outputURL: out)
            exportProgressText = "Saved to \(resultURL.path)"
        } catch {
            exportProgressText = "Failed: \(error.localizedDescription)"
        }
        exporting = false
    }
    
    private func togglePlayPause() {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }
    
    private func seekToTime(_ time: Double, pause: Bool = true) {
        guard let player = player else { return }
        
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { completed in
            if completed && pause {
                // Pause after seeking to let user see the exact frame
                DispatchQueue.main.async {
                    self.player?.pause()
                    self.isPlaying = false
                }
            }
        }
    }
    
    private func addPlaybackObservers(to item: AVPlayerItem) {
        // Observe when video finishes playing
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            self.isPlaying = false
        }
        
        // Observe playback state changes
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemPlaybackStalled,
            object: item,
            queue: .main
        ) { _ in
            self.isPlaying = false
        }
    }

}

private extension CGSize {
    var widthInt: Int {
        get { Int(self.width.rounded()) }
        set { self.width = CGFloat(newValue) }
    }
    var heightInt: Int {
        get { Int(self.height.rounded()) }
        set { self.height = CGFloat(newValue) }
    }
}
