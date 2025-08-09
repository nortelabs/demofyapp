import SwiftUI
import AVFoundation
import AVKit
import AppKit

struct ContentView: View {
    // State
    @State private var recordingState: RecordingState = .idle
    @State private var simulatorDevice: String = "booted"
    @State private var recordingURL: URL?
    @State private var videoURL: URL?
    @State private var player: AVPlayer?

    @State private var framePreset: FramePresetKey = .iphone16proBlack
    @State private var frameImageURL: URL?
    @State private var frameImage: NSImage?
    @State private var screenRect: ScreenRect = framePresets.first!.defaultScreen
    @State private var showGuides: Bool = true

    @State private var scale: Double = 100 // percent
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
    private let ffmpeg = FFmpegRunner()

    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 12) {
                // Preview
                GroupBox("Preview") {
                    GeometryReader { geo in
                        let aspect = stageAspect() // frame or video-based
                        ZStack {
                            Color(NSColor.windowBackgroundColor)
                            VideoFramePreview(
                                player: player,
                                overlayImage: frameImage,
                                screen: screenRect,
                                scale: scale,
                                offsetX: offsetX,
                                offsetY: offsetY,
                                showGuides: showGuides
                            )
                        }
                        .aspectRatio(aspect, contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                    .frame(minHeight: 420)
                }

                // Trim
                GroupBox("Trim") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Start \(formatTime(trimStart))")
                            Slider(value: $trimStart, in: 0...max(0, duration - 0.1), step: 1) { _ in
                                trimStart = min(trimStart, trimEnd)
                            }
                        }
                        HStack {
                            Text("End \(formatTime(trimEnd))")
                            Slider(value: $trimEnd, in: 0...duration, step: 1) { _ in
                                trimEnd = max(trimEnd, trimStart)
                            }
                        }
                        Text("Duration: \(formatTime(max(0, trimEnd - trimStart)))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(minWidth: 620)

            // Right controls
            VStack(spacing: 12) {
                GroupBox("Record iOS Simulator") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Device:")
                            TextField("booted", text: $simulatorDevice)
                                .textFieldStyle(.roundedBorder)
                        }
                        HStack {
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
                            } else {
                                Button(role: .destructive) {
                                    recorder.stopRecording()
                                    recordingState = .recorded
                                } label: {
                                    Label("Stop", systemImage: "stop.fill")
                                }
                            }
                            Button("Reset") {
                                recorder.stopRecording()
                                recordingURL = nil
                                recordingState = .idle
                            }
                        }
                        if let path = recordingURL?.path {
                            HStack {
                                Image(systemName: "folder")
                                Text(path).lineLimit(1).truncationMode(.middle)
                                Spacer()
                                Button("Import") {
                                    loadVideo(from: recordingURL)
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                }

                GroupBox("Source") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Button {
                                if let url = askOpenURL(allowed: ["mp4", "mov", "m4v"]) {
                                    loadVideo(from: url)
                                }
                            } label: { Label("Import Video", systemImage: "square.and.arrow.down") }

                            Button {
                                if let url = askOpenURL(allowed: ["png"]) {
                                    frameImageURL = url
                                    frameImage = NSImage(contentsOf: url)
                                    framePreset = .custom
                                }
                            } label: { Label("Upload Frame PNG", systemImage: "photo") }
                        }
                        // Frame preset picker
                        Picker("Frame Preset", selection: $framePreset) {
                            ForEach(framePresets) { p in
                                Text(p.label).tag(p.key)
                            }
                        }
                        .onChange(of: framePreset) { new in
                            let p = framePresets.first { $0.key == new }!
                            screenRect = p.defaultScreen
                            if let name = p.bundleImageName, let url = Bundle.main.url(forResource: name, withExtension: "png") {
                                frameImageURL = url
                                frameImage = NSImage(contentsOf: url)
                            } else if new == .custom {
                                // keep current custom image
                            }
                        }

                        Toggle("Show Guides", isOn: $showGuides)

                        Divider()

                        // Screen window sliders
                        VStack(alignment: .leading) {
                            HStack { Text("Left"); Slider(value: $screenRect.x, in: 0...30, step: 0.1); Text("\(screenRect.x, specifier: "%.1f")%").frame(width: 60) }
                            HStack { Text("Top"); Slider(value: $screenRect.y, in: 0...20, step: 0.1); Text("\(screenRect.y, specifier: "%.1f")%").frame(width: 60) }
                            HStack { Text("Width"); Slider(value: $screenRect.w, in: 50...100, step: 0.1); Text("\(screenRect.w, specifier: "%.1f")%").frame(width: 60) }
                            HStack { Text("Height"); Slider(value: $screenRect.h, in: 60...100, step: 0.1); Text("\(screenRect.h, specifier: "%.1f")%").frame(width: 60) }
                        }

                        HStack {
                            Button("Fit to Preset") {
                                if let p = framePresets.first(where: { $0.key == framePreset }) {
                                    screenRect = p.defaultScreen
                                }
                            }
                            Button("Reset Screen") {
                                screenRect = .init(x: 0, y: 0, w: 100, h: 100)
                                scale = 100; offsetX = 0; offsetY = 0
                            }
                        }
                    }
                }

                GroupBox("Inside Screen Adjustments") {
                    VStack(alignment: .leading) {
                        HStack { Text("Zoom"); Slider(value: $scale, in: 10...400, step: 1); Text("\(Int(scale))%").frame(width: 60) }
                        HStack { Text("Offset X"); Slider(value: $offsetX, in: -100...100, step: 1); Text("\(Int(offsetX))").frame(width: 60) }
                        HStack { Text("Offset Y"); Slider(value: $offsetY, in: -100...100, step: 1); Text("\(Int(offsetY))").frame(width: 60) }
                    }
                }

                GroupBox("Export") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Format")
                            Picker("", selection: $outputFormat) {
                                ForEach(ExportFormat.allCases) { fmt in Text(fmt.rawValue.uppercased()).tag(fmt) }
                            }
                            .pickerStyle(.segmented)
                            Spacer()
                            Text("Canvas")
                            TextField("Width", value: $canvas.width, formatter: NumberFormatter())
                                .frame(width: 70)
                            Text("×")
                            TextField("Height", value: $canvas.height, formatter: NumberFormatter())
                                .frame(width: 70)
                        }

                        HStack(spacing: 12) {
                            Button {
                                exportWithAVFoundation()
                            } label: { Label("Export (AVFoundation)", systemImage: "arrow.down.doc") }
                            .disabled(videoURL == nil)
                            if exporting { ProgressView().controlSize(.small) }
                            if !exportProgressText.isEmpty { Text(exportProgressText).font(.caption).foregroundColor(.secondary) }
                        }

                        // Optional: FFmpeg — run a raw command if you prefer parity with the web prototype
                        Button {
                            guard let cmd = makeFFmpegCommandPreview() else { return }
                            let panel = NSSavePanel()
                            panel.nameFieldStringValue = "demofy-output.\(outputFormat.rawValue)"
                            panel.begin { resp in
                                guard resp == .OK, let outURL = panel.url else { return }
                                // Replace output filename in command preview
                                let safeCommand = cmd.replacingOccurrences(of: "demofy-output.\(self.outputFormat.rawValue)", with: outURL.lastPathComponent)
                                let cwd = outURL.deletingLastPathComponent()
                                exportProgressText = "Running FFmpeg…"
                                ffmpeg.runRaw(command: safeCommand, in: cwd, onProgress: { prog in
                                    DispatchQueue.main.async {
                                        self.exportProgressText = "FFmpeg time=\(formatTime(prog.seconds))"
                                    }
                                }, completion: { result in
                                    DispatchQueue.main.async {
                                        switch result {
                                        case .success: self.exportProgressText = "FFmpeg export completed"
                                        case .failure(let err): self.exportProgressText = "FFmpeg failed: \(err.localizedDescription)"
                                        }
                                    }
                                })
                            }
                        } label: { Label("Export via FFmpeg (advanced)", systemImage: "terminal") }
                        .disabled(videoURL == nil)
                    }
                }
                Spacer()
            }
            .frame(width: 420)
        }
        .padding(12)
        .onDisappear {
            player?.pause()
        }
    }

    // MARK: - Helpers

    private func stageAspect() -> CGFloat {
        if let img = frameImage { return img.size.width / img.size.height }
        if let url = videoURL {
            let asset = AVURLAsset(url: url)
            if let track = asset.tracks(withMediaType: .video).first {
                let nat = track.naturalSize.applying(track.preferredTransform)
                let sz = CGSize(width: abs(nat.width), height: abs(nat.height))
                if sz.height > 0 { return sz.width / sz.height }
            }
        }
        return 9/19.5
    }

    private func loadVideo(from url: URL?) {
        guard let url else { return }
        videoURL = url
        let asset = AVURLAsset(url: url)
        let secs = CMTimeGetSeconds(asset.duration)
        duration = secs.isFinite ? secs : 0
        trimStart = 0
        trimEnd = duration
        let item = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: item)
    }

    private func askOpenURL(allowed: [String]) -> URL? {
        let p = NSOpenPanel()
        p.allowedFileTypes = allowed
        p.allowsMultipleSelection = false
        p.canChooseDirectories = false
        return p.runModal() == .OK ? p.url : nil
    }

    private func askSaveURL(suggested: String) -> URL? {
        let p = NSSavePanel()
        p.nameFieldStringValue = suggested
        return p.runModal() == .OK ? p.url : nil
    }

    private func exportWithAVFoundation() {
        guard let input = videoURL else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "demofy-output.\(outputFormat.rawValue)"
        panel.begin { resp in
            guard resp == .OK, let out = panel.url else { return }
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
            exporter.export(inputURL: input, frameImageURL: frameURL, config: cfg, outputURL: out) { result in
                DispatchQueue.main.async {
                    exporting = false
                    switch result {
                    case .success(let url):
                        exportProgressText = "Saved to \(url.path)"
                    case .failure(let error):
                        exportProgressText = "Failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    // Create an FFmpeg command string similar to the web prototype for parity
    private func makeFFmpegCommandPreview() -> String? {
        guard let input = videoURL else { return nil }
        // We only return command text; FFmpeg must be installed on PATH or provided in app.
        let outW = Int(canvas.width), outH = Int(canvas.height)
        let sx = Int((screenRect.x / 100.0) * Double(outW))
        let sy = Int((screenRect.y / 100.0) * Double(outH))
        let sw = max(8, Int((screenRect.w / 100.0) * Double(outW)))
        let sh = max(8, Int((screenRect.h / 100.0) * Double(outH)))

        let extraZoom = max(0.1, scale / 100.0)
        let offX = Int((offsetX / 100.0) * Double(sw) / 2.0)
        let offY = Int((offsetY / 100.0) * Double(sh) / 2.0)

        var trim = ""
        if trimEnd > trimStart {
            let s = Int(trimStart.rounded(.towardZero))
            let e = Int(trimEnd.rounded(.towardZero))
            trim = "-ss \(s) -to \(e) "
        }
        let frameName: String? = {
            if let url = frameImageURL { return url.lastPathComponent }
            if let name = framePresets.first(where: { $0.key == framePreset })?.bundleImageName { return "\(name).png" }
            return nil
        }()

        let vf1 = "[0:v]scale=\(sw):\(sh):force_original_aspect_ratio=increase," +
                  "crop=\(sw):\(sh):\(sw/2 - Int(Double(sw)/(2*extraZoom)) + offX):\(sh/2 - Int(Double(sh)/(2*extraZoom)) + offY)[vid];" +
                  "color=c=black:size=\(outW)x\(outH)[bg];[bg][vid]overlay=\(sx):\(sy)[base]"

        var cmd = "ffmpeg \(trim)-i \"\(input.lastPathComponent)\" "
        if let frameName {
            cmd += "-i \"\(frameName)\" -filter_complex \"\(vf1);[1:v]scale=\(outW):\(outH)[frm];[base][frm]overlay=0:0:format=auto\" -pix_fmt yuv420p -c:a copy -movflags +faststart \"demofy-output.\(outputFormat.rawValue)\""
        } else {
            cmd += "-filter_complex \"\(vf1)\" -pix_fmt yuv420p -c:a copy -movflags +faststart \"demofy-output.\(outputFormat.rawValue)\""
        }
        return cmd
    }
}

private extension CGSize {
    var width: Int {
        get { Int(self.width.rounded()) }
        set { self = CGSize(width: CGFloat(newValue), height: self.height) }
    }
    var height: Int {
        get { Int(self.height.rounded()) }
        set { self = CGSize(width: self.width, height: CGFloat(newValue)) }
    }
}