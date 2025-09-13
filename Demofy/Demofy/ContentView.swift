import SwiftUI
import AVFoundation
import AVKit
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    // State
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("customSaveLocationPath") private var customSaveLocationPath: String = ""
    @State private var recordingState: RecordingState = .idle
    @State private var simulatorDevice: SimulatorDevice?
    @State private var recordingURL: URL?
    @State private var customSaveLocation: URL?
    @State private var videoURL: URL?
    @State private var player: AVPlayer?

    @State private var framePreset: FramePresetKey = framePresets.first(where: { $0.bundleImageName != nil })?.key ?? framePresets.first?.key ?? ""
    @State private var frameImage: NSImage?
    @State private var screenRect: ScreenRect = framePresets.first(where: { $0.bundleImageName != nil })?.defaultScreen ?? framePresets.first?.defaultScreen ?? ScreenRect(x: 6.5, y: 3.0, w: 87.0, h: 94.0)

    @State private var scale: Double = 100 // percent - 100% for proper fitting
    @State private var offsetX: Double = 0 // -100..100
    @State private var offsetY: Double = 0 // -100..100
    @State private var videoFitMode: VideoFitMode = .fill

    @State private var duration: Double = 0
    @State private var trimStart: Double = 0
    @State private var trimEnd: Double = 0
    @State private var isPlaying: Bool = false

    @State private var outputFormat: ExportFormat = .mp4
    @State private var exporting = false
    @State private var exportProgressText = ""

    private let recorder = SimulatorRecorder()
    private let exporter = AVFExporter()

    var body: some View {
        HStack(spacing: 24) {
            leftPanel
            rightPanel
        }
        .padding(24)
        .background(Color.background.ignoresSafeArea())
        .onAppear {
            // Don't load any frame by default - show popup instead
            
            // Auto-detect running iOS simulator
            simulatorDevice = recorder.getDefaultDevice()
            if let device = simulatorDevice {
                print("🔍 Auto-detected simulator device: \(device.displayName)")
            } else {
                print("⚠️ No running simulators detected")
            }
            
            // Load saved custom save location
            if !customSaveLocationPath.isEmpty {
                customSaveLocation = URL(fileURLWithPath: customSaveLocationPath)
            }
        }
        .onDisappear {
            player?.pause()
            isPlaying = false
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem)) { _ in
            player?.seek(to: .zero)
            isPlaying = false
        }
    }

    // MARK: - UI Sections

    private var leftPanel: some View {
        VStack(spacing: 20) {
            previewSection
            timelineSection
        }
        .frame(minWidth: 580)
    }

    private var rightPanel: some View {
        ScrollView {
            VStack(spacing: 20) {
                recordingSection
                sourceAndFrameSection
                exportSettingsSection
            }
            .padding(.vertical, 8)
        }
        .frame(width: 420)
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
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
                                    .stroke(Color.blue, lineWidth: 2) // Added a prominent blue border
                            )
                        
                        Image(systemName: isDarkMode ? "sun.max.fill" : "moon.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(isDarkMode ? .orangeWeb : .oxfordBlue) // Visible colors for both modes
                    }
                }
                .buttonStyle(.borderless)
                .help(isDarkMode ? "Switch to Light Mode" : "Switch to Dark Mode")
                .floating()
            }
            
            ZStack {
                // Modern background that adapts to dark mode
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.previewBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.primaryBrand.opacity(0.3), lineWidth: 2)
                    )
                    .shadow(color: Color.primaryBrand.opacity(0.1), radius: 20, x: 0, y: 8)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                
                PreviewStageView(
                    player: player,
                    frameImage: frameImage,
                    screenRect: screenRect,
                    scale: scale,
                    offsetX: offsetX,
                    offsetY: offsetY,
                    videoFitMode: videoFitMode,
                    stageAspectRatio: stageAspectRatio
                )
            }
            .frame(minHeight: 450)
        }
    }

    private var timelineSection: some View {
        TimelineSectionView(
            duration: duration,
            trimStart: $trimStart,
            trimEnd: $trimEnd,
            isPlaying: isPlaying,
            isDarkMode: $isDarkMode, // Pass isDarkMode as a binding
            togglePlayPause: togglePlayPause,
            seekToTime: { t, p in seekToTime(t, pause: p) }
        )
    }

    private var recordingSection: some View {
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
                
                LabeledControl("Device") {
                    HStack {
                        if let device = simulatorDevice {
                            Text(device.displayName)
                                .foregroundColor(.primary)
                                .font(.system(.body, design: .default))
                            Spacer()
                            Text(device.id)
                                .foregroundColor(.secondary)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        } else {
                            Text("No simulator running")
                                .foregroundColor(.secondary)
                                .font(.system(.body, design: .default))
                            Spacer()
                        }
                        
                        Button {
                            refreshSimulatorDevices()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                LabeledControl("Save Location") {
                    HStack(spacing: 8) {
                        if let customLocation = customSaveLocation {
                            Text(customLocation.lastPathComponent)
                                .foregroundColor(.primary)
                                .font(.system(.body, design: .monospaced))
                                .truncationMode(.middle)
                            Text("(\(customLocation.deletingLastPathComponent().path))")
                                .foregroundColor(.secondary)
                                .font(.caption)
                                .truncationMode(.middle)
                        } else {
                            let defaultPath = getDefaultSaveLocation()
                            Text("(\(defaultPath.path))")
                                .foregroundColor(.secondary)
                                .font(.caption)
                                .truncationMode(.middle)
                        }
                        
                        Spacer()
                        
                        Button {
                            chooseSaveLocation()
                        } label: {
                            Label("Choose", systemImage: "folder")
                        }
                        .modernButton(.secondary, size: .small)
                        
                        if customSaveLocation != nil {
                            Button {
                                customSaveLocation = nil
                                customSaveLocationPath = ""
                                print("📁 Reset to default save location")
                            } label: {
                                Label("Reset", systemImage: "xmark.circle")
                            }
                            .modernButton(.ghost, size: .small)
                        }
                    }
                }
                
                HStack(spacing: 12) {
                    if recordingState != .recording {
                        Button {
                            startRecording()
                        } label: {
                            Label("Start Recording", systemImage: "record.circle.fill")
                        }
                        .modernButton(.primary, size: .medium)
                    } else {
                        Button {
                            stopRecording()
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
    }

    private var sourceAndFrameSection: some View {
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
                Button {
                    if let url = askOpenURL(allowed: [.movie, .mpeg4Movie]) {
                        Task { await loadVideo(from: url) }
                    }
                } label: { 
                    Label("Import Video", systemImage: "square.and.arrow.down") 
                }
                .modernButton(.secondary, size: .medium)

                LabeledControl("Device Frame") {
                    Picker("Frame Preset", selection: $framePreset) {
                        ForEach(framePresets) { p in
                            Text(p.label).tag(p.key)
                        }
                    }
                    .pickerStyle(.menu)
                    .overlay {
                        if frameImage == nil {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.blue, lineWidth: 3)
                                .scaleEffect(1.05)
                                .opacity(0.8)
                                .animation(
                                    Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                                    value: frameImage == nil
                                )
                        }
                    }
                    .onChange(of: framePreset) { _, new in
                        applyFramePreset(new)
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
    }

    private var exportSettingsSection: some View {
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

    private func applyFramePreset(_ newKey: FramePresetKey) {
        guard let p = framePresets.first(where: { $0.key == newKey }) else { return }
        screenRect = p.defaultScreen
        guard let name = p.bundleImageName else {
            frameImage = nil
            Task { await autoFitVideo(); await updateStageAspect() }
            return
        }
        func loadImage(named: String) -> NSImage? {
            if let url = Bundle.main.url(forResource: named, withExtension: "png"),
               let img = NSImage(contentsOf: url)?.trimmingTransparentPixels() {
                return img
            }
            return nil
        }
        let img = loadImage(named: name) ?? loadImage(named: name.replacingOccurrences(of: "Frames/", with: ""))
        if let img {
            frameImage = img
            if let detected = img.screenRectFromTransparencyPercent() {
                // Inset slightly to avoid edge bleed from anti-aliasing
                screenRect = insetScreenRect(detected, by: 1.0)
            }
            Task { await autoFitVideo(); await updateStageAspect() }
        } else {
            print("⚠️  [ContentView] Frame image not found in app bundle!")
            print("    Searched for: \(name).png and \(name.replacingOccurrences(of: "Frames/", with: "")).png")
            print("    Solution: Add PNG frame files to your Xcode project target:")
            print("    1. In Xcode, right-click your project in the navigator")
            print("    2. Choose 'Add Files to [ProjectName]'")
            print("    3. Select the .png files from Demofy/Frames/")
            print("    4. Make sure 'Add to target' is checked for your app target")
            print("    5. Clean and rebuild the project")
            frameImage = nil
        }
    }

    private func insetScreenRect(_ r: ScreenRect, by percent: Double) -> ScreenRect {
        let dx = max(0, percent)
        let dy = max(0, percent)
        let nx = min(100, max(0, r.x + dx))
        let ny = min(100, max(0, r.y + dy))
        let nw = max(0, r.w - 2 * dx)
        let nh = max(0, r.h - 2 * dy)
        return ScreenRect(x: nx, y: ny, w: nw, h: nh)
    }

    @MainActor
    private func loadVideo(from url: URL?) async {
        guard let url else { return }

        // Note: AVAudioSession is iOS-only, not needed on macOS
        // macOS handles audio routing automatically

        do {
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("Video file does not exist at path: \(url.path)")
                return
            }
            guard FileManager.default.isReadableFile(atPath: url.path) else {
                print("Video file is not readable at path: \(url.path)")
                return
            }
            
            let asset = AVURLAsset(url: url)
            
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
            
            // ✅ Orientation-corrected AVPlayerItem
            var item: AVPlayerItem
            do {
                let videoTracks = try await asset.loadTracks(withMediaType: .video)
                if let videoTrack = videoTracks.first {
                    let duration = try await asset.load(.duration)
                    // Build a video-only composition to avoid creating any audio pipeline during preview
                    let comp = AVMutableComposition()
                    guard let compVideo = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                        item = AVPlayerItem(asset: asset)
                        throw NSError(domain: "Demofy", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create video track in composition"])
                    }
                    try compVideo.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: videoTrack, at: .zero)
                    
                    let transform = try await videoTrack.load(.preferredTransform)
                    let naturalSize = try await videoTrack.load(.naturalSize)
                    let correctedSize = naturalSize.applying(transform)
                    let renderSize = CGSize(width: abs(correctedSize.width), height: abs(correctedSize.height))
                    
                    let instruction = AVMutableVideoCompositionInstruction()
                    instruction.timeRange = CMTimeRange(start: .zero, duration: comp.duration)
                    let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compVideo)
                    layerInstruction.setTransform(transform, at: .zero)
                    instruction.layerInstructions = [layerInstruction]
                    
                    let videoComposition = AVMutableVideoComposition()
                    videoComposition.instructions = [instruction]
                    videoComposition.renderSize = renderSize
                    videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
                    
                    item = AVPlayerItem(asset: comp)
                    item.videoComposition = videoComposition
                } else {
                    item = AVPlayerItem(asset: asset)
                }
            } catch {
                print("Warning: couldn't build oriented, video-only composition — falling back to raw item:", error)
                item = AVPlayerItem(asset: asset)
            }
            
            videoURL = url
            duration = newDuration.isFinite ? newDuration : 0
            trimStart = 0
            trimEnd = duration
            
            player = AVPlayer(playerItem: item)
            // Ensure no audio pipeline is used for preview
            player?.isMuted = true
            item.tracks.filter { $0.assetTrack?.mediaType == .audio }.forEach { $0.isEnabled = false }
            
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
            
        } catch {
            print("Failed to load video: \(error.localizedDescription)")
            print("Error details: \(error)")
            
            // Show user-friendly error message
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Failed to Import Video"
                alert.informativeText = "There was an error loading the video file. This might be due to:\n\n• Unsupported video format or codec\n• Corrupted video file\n• File access permissions\n• Core Foundation factory registration issues\n\nTry a different video file or restart the app if the issue persists."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }

    
    private func autoFitVideo() async {
        // Reset to default fitting - the video layer will handle the fitting automatically
        // based on the videoGravity setting in VideoFramePreview
        scale = 100.0
        offsetX = 0
        offsetY = 0
        videoFitMode = .fit
    }


    private func askOpenURL(allowed: [UTType]) -> URL? {
        let p = NSOpenPanel()
        p.allowedContentTypes = allowed
        p.allowsMultipleSelection = false
        p.canChooseDirectories = false
        return p.runModal() == .OK ? p.url : nil
    }

    // Choose custom save location
    private func chooseSaveLocation() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose Save Location"
        panel.message = "Select a folder where recordings will be saved"
        
        if panel.runModal() == .OK, let url = panel.url {
            customSaveLocation = url
            customSaveLocationPath = url.path
            print("📁 Custom save location set to: \(url.path)")
        }
    }
    
    // Refresh simulator device list
    private func refreshSimulatorDevices() {
        simulatorDevice = recorder.getDefaultDevice()
        if let device = simulatorDevice {
            print("🔄 Refreshed simulator devices - Found: \(device.displayName)")
        } else {
            print("🔄 Refreshed simulator devices - No running simulators found")
        }
    }
    
    // Get default save location path for display
    private func getDefaultSaveLocation() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("Demofy")
    }
    
    // Get save location for recordings (custom or default)
    private func getRecordingSaveURL() -> URL {
        let baseFolder: URL
        
        if let customLocation = customSaveLocation {
            baseFolder = customLocation
        } else {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let demofyFolder = documentsPath.appendingPathComponent("Demofy")
            try? FileManager.default.createDirectory(at: demofyFolder, withIntermediateDirectories: true)
            baseFolder = demofyFolder
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let fileName = "demofy-recording_\(dateFormatter.string(from: Date())).mp4"
        
        return baseFolder.appendingPathComponent(fileName)
    }
    
    // Start recording with auto-save
    private func startRecording() {
        let url = getRecordingSaveURL()
        let locationDescription = customSaveLocation != nil ? "custom location" : "default location"
        
        // Show the user exactly where the file will be saved
        print("📁 Recording will be saved to \(locationDescription):")
        print("   Full path: \(url.path)")
        print("   Directory: \(url.deletingLastPathComponent().path)")
        print("   Filename: \(url.lastPathComponent)")
        
        do {
            try recorder.startRecording(saveTo: url, device: simulatorDevice)
            recordingURL = url
            recordingState = .recording
            print("🎬 Recording started successfully")
        } catch {
            print("❌ Failed to start recording: \(error)")
        }
    }
    
    // Stop recording and auto-load video
    private func stopRecording() {
        recorder.stopRecording()
        recordingState = .recorded
        
        // Auto-load the recorded video into preview
        if let url = recordingURL {
            print("📹 Recording stopped. File should be at: \(url.path)")
            
            // Check if file exists and auto-load
            Task {
                // Wait a moment for file to be fully written
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
                if FileManager.default.fileExists(atPath: url.path) {
                    print("✅ Recording file found, loading into preview...")
                    await loadVideo(from: url)
                } else {
                    print("❌ Recording file not found at: \(url.path)")
                    
                    // Try to find files in the directory
                    let directory = url.deletingLastPathComponent()
                    do {
                        let contents = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey], options: [])
                        let recentFiles = contents.filter { $0.pathExtension == "mp4" }
                            .sorted { (url1, url2) in
                                let date1 = try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                                let date2 = try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                                return (date1 ?? Date.distantPast) > (date2 ?? Date.distantPast)
                            }
                        
                        if let mostRecent = recentFiles.first {
                            print("🔍 Found recent recording: \(mostRecent.lastPathComponent)")
                            await loadVideo(from: mostRecent)
                        } else {
                            print("🔍 No MP4 files found in directory")
                        }
                    } catch {
                        print("❌ Error checking directory contents: \(error)")
                    }
                }
            }
        }
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
        
        // Resolve frame image URL from preset, if any
        var frameURL: URL?
        if let preset = framePresets.first(where: { $0.key == framePreset }),
           let name = preset.bundleImageName {
            if let bURL = Bundle.main.url(forResource: name, withExtension: "png") {
                frameURL = bURL
            } else {
                let nameWithoutPrefix = name.replacingOccurrences(of: "Frames/", with: "")
                if let bURL = Bundle.main.url(forResource: nameWithoutPrefix, withExtension: "png") {
                    frameURL = bURL
                } else {
                    print("⚠️  [Export] Frame image not found for export: \(name).png")
                    frameURL = nil
                }
            }
        }

        // Choose a canvas that matches the selected frame's aspect ratio to avoid letterboxing
        func makeEven(_ v: Int) -> Int { v % 2 == 0 ? v : v + 1 }
        var canvasWidth = 1080
        var canvasHeight = 1920
        if let frameURL, let rawImg = NSImage(contentsOf: frameURL) {
            // Match the trimmed frame we use for preview/overlay, so screenRect percentages
            // align 1:1 with the export canvas.
            let img = rawImg.trimmingTransparentPixels() ?? rawImg
            let w = img.size.width
            let h = img.size.height
            if w > 0 && h > 0 {
                let aspect = w / h
                // Keep width fixed at 1080 and compute even height that matches frame aspect
                let computedHeight = Int((CGFloat(canvasWidth) / aspect).rounded())
                canvasHeight = makeEven(max(2, computedHeight))
            }
        }

        let cfg = DemofyConfig(
            outputFormat: outputFormat.rawValue,
            canvas: .init(width: canvasWidth, height: canvasHeight),
            trim: .init(start: trimStart, end: trimEnd),
            screenRect: screenRect,
            scale: scale / 100.0,
            offset: .init(x: offsetX / 100.0, y: offsetY / 100.0),
            videoFitMode: videoFitMode
        )

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
