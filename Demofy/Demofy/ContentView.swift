import SwiftUI
import AVFoundation
import AVKit
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    // State
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

    @State private var scale: Double = 110 // percent - slightly zoomed to ensure proper fitting
    @State private var offsetX: Double = 0 // -100..100
    @State private var offsetY: Double = 0 // -100..100

    @State private var duration: Double = 0
    @State private var trimStart: Double = 0
    @State private var trimEnd: Double = 0

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
                        Image(systemName: "play.rectangle.fill")
                            .font(.title2)
                            .foregroundColor(.accent)
                        Text("Preview")
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                    }
                    
                    ZStack {
                        // Background with gradient
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [Color(.systemGray6), Color(.systemGray5)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                        
                        GeometryReader { geo in
                            let aspect = stageAspectRatio
                            ZStack {
                                VideoFramePreview(
                                    player: player,
                                    overlayImage: frameImage,
                                    screen: screenRect,
                                    scale: scale,
                                    offsetX: offsetX,
                                    offsetY: offsetY,
                                    showGuides: showGuides
                                )
                                .frame(width: geo.size.width - 40, height: geo.size.height - 40)
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                                
                                // Enhanced empty state
                                if frameImage == nil {
                                    VStack(spacing: 20) {
                                        ZStack {
                                            Circle()
                                                .fill(
                                                    LinearGradient(
                                                        colors: [.accent.opacity(0.1), .accent.opacity(0.05)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(width: 80, height: 80)
                                            
                                            Image(systemName: "iphone.gen3")
                                                .font(.system(size: 32, weight: .light))
                                                .foregroundColor(.accent)
                                        }
                                        
                                        VStack(spacing: 8) {
                                            Text("Ready to Create")
                                                .font(.title3)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.primary)
                                            
                                            Text("Select a device frame to get started")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                                .multilineTextAlignment(.center)
                                        }
                                        
                                        HStack(spacing: 8) {
                                            Image(systemName: "arrow.right.circle.fill")
                                                .foregroundColor(.accent)
                                            Text("Choose from Frame Preset menu")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(.ultraThinMaterial, in: Capsule())
                                    }
                                    .padding(32)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                                    .shadow(radius: 12, y: 6)
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
                        Image(systemName: "timeline.selection")
                            .font(.title2)
                            .foregroundColor(.accent)
                        Text("Timeline")
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        SliderWithValue(
                            "Start Time",
                            value: $trimStart,
                            in: 0...max(1, duration - 0.1),
                            step: 1,
                            format: "%.0f",
                            unit: "s"
                        ) { _ in
                            trimStart = min(trimStart, trimEnd)
                        }
                        
                        SliderWithValue(
                            "End Time",
                            value: $trimEnd,
                            in: 0...max(1, duration),
                            step: 1,
                            format: "%.0f",
                            unit: "s"
                        ) { _ in
                            trimEnd = max(trimEnd, trimStart)
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
                            .fill(
                                LinearGradient(
                                    colors: [Color(.systemGray6), Color(.systemGray5)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
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
                                        .background(Color(.systemGray4))
                                    
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
                                .fill(
                                    LinearGradient(
                                        colors: [Color(.systemGray6), Color(.systemGray5)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color(.systemGray4), lineWidth: 1)
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
                                        frameImage = NSImage(contentsOf: url)
                                        framePreset = .custom
                                        Task { await updateStageAspect() }
                                    }
                                } label: { 
                                    Label("Custom Frame", systemImage: "photo") 
                                }
                                .modernButton(.secondary, size: .medium)
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
                                            frameImage = NSImage(contentsOf: url)
                                            Task { await updateStageAspect() }
                                        } else {
                                            // Try without the Frames/ prefix
                                            let nameWithoutPrefix = name.replacingOccurrences(of: "Frames/", with: "")
                                            if let url = Bundle.main.url(forResource: nameWithoutPrefix, withExtension: "png") {
                                                frameImageURL = url
                                                frameImage = NSImage(contentsOf: url)
                                                Task { await updateStageAspect() }
                                            }
                                        }
                                    } else if new == .custom {
                                        // keep current custom image
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(.systemGray6), Color(.systemGray5)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color(.systemGray4), lineWidth: 1)
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
                                .fill(
                                    LinearGradient(
                                        colors: [Color(.systemGray6), Color(.systemGray5)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                )
                        )
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(width: 420)
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.systemGray6).opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .onAppear {
            // Don't load any frame by default - show popup instead
        }
        .onDisappear {
            player?.pause()
            // Remove notification observers
            NotificationCenter.default.removeObserver(self)
        }
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
        
        // Check if file exists and is accessible
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("Video file does not exist at path: \(url.path)")
            return
        }
        
        // Check file permissions
        guard FileManager.default.isReadableFile(atPath: url.path) else {
            print("Video file is not readable at path: \(url.path)")
            return
        }
        
        videoURL = url
        let asset = AVURLAsset(url: url)
        
        do {
            // Load basic asset properties first
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
            
            // Load duration
            let newDuration = try await asset.load(.duration).seconds
            duration = newDuration.isFinite ? newDuration : 0
            trimStart = 0
            trimEnd = duration
            
            // Create player item and player
            let item = AVPlayerItem(asset: asset)
            player = AVPlayer(playerItem: item)
            
            // Add error observation
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemFailedToPlayToEndTime,
                object: item,
                queue: .main
            ) { notification in
                if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                    print("Player failed to play to end time: \(error.localizedDescription)")
                }
            }
            
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemNewErrorLogEntry,
                object: item,
                queue: .main
            ) { notification in
                if let errorLog = notification.object as? AVPlayerItemErrorLog {
                    print("Player error log entry: \(errorLog)")
                }
            }
            
            // Start playback automatically
            player?.play()
            
            Task { await updateStageAspect() }
        } catch {
            print("Failed to load video: \(error.localizedDescription)")
            print("Error details: \(error)")
        }
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
            offset: .init(x: offsetX / 100.0, y: offsetY / 100.0)
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
