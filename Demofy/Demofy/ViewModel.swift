import Foundation
import Combine
import AppKit
import UniformTypeIdentifiers

class ViewModel: ObservableObject {
    @Published var isRecording = false
        @Published var videoURL: URL?
    @Published var droppedVideoURL: URL?
    @Published var availableFrames: [URL] = []
    @Published var selectedFrameURL: URL?
    @Published var processedVideoURL: URL?
    @Published var isProcessing = false
    @Published var processingError: String?
    @Published var isFFmpegInstalled = false

    private var ffmpegPath: String?
    private var recordingProcess: Process?
    private var processingProcess: Process?

    init() {
        loadFrames()
    }

    func startRecording(at url: URL) {
        isRecording = true
        self.videoURL = url

        recordingProcess = Process()
        recordingProcess?.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        recordingProcess?.arguments = ["simctl", "io", "booted", "recordVideo", "--codec=h264", url.path]

        do {
            try recordingProcess?.run()
        } catch {
            print("Error starting recording: \(error)")
            isRecording = false
        }
    }

    func showSavePanelAndStartRecording() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType.mpeg4Movie]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        savePanel.nameFieldStringValue = "demofy_\(dateFormatter.string(from: Date())).mp4"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                self.startRecording(at: url)
            }
        }
    }

    func stopRecording() {
        recordingProcess?.interrupt() // Sends SIGINT to stop the recording gracefully
        isRecording = false
        checkForFFmpeg()
    }

    func checkForFFmpeg() {
        // 1. Check common Homebrew paths first for efficiency
        let possiblePaths = ["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg"]
        for path in possiblePaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                self.ffmpegPath = path
                self.isFFmpegInstalled = true
                return
            }
        }

        // 2. If not found, fall back to using the `which` command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["ffmpeg"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let foundPath = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)

            if let path = foundPath, !path.isEmpty {
                self.ffmpegPath = path
                self.isFFmpegInstalled = true
            } else {
                self.isFFmpegInstalled = false
                self.processingError = "FFmpeg not found. Please install it to use video processing features."
            }
        } catch {
            self.isFFmpegInstalled = false
            self.processingError = "Error checking for FFmpeg: \(error.localizedDescription)"
        }
    }

    func revealInFinder(url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func loadFrames() {
        guard let framesURL = Bundle.main.url(forResource: "Frames", withExtension: nil) else {
            print("Frames directory not found in bundle. Make sure it's added to the project as a folder reference (blue folder).")
            return
        }

        do {
            let frameURLs = try FileManager.default.contentsOfDirectory(at: framesURL, includingPropertiesForKeys: nil)
            self.availableFrames = frameURLs.filter { $0.pathExtension.lowercased() == "png" }
            self.selectedFrameURL = self.availableFrames.first
        } catch {
            print("Error loading frames: \(error)")
        }
    }

    func processVideo(outputURL: URL) {
        guard let video = droppedVideoURL, let frame = selectedFrameURL else {
            processingError = "Please drop a video file and select a frame."
            return
        }

        guard isFFmpegInstalled else {
            processingError = "Cannot process video, FFmpeg is not installed."
            return
        }

        isProcessing = true
        processingError = nil

        processingProcess = Process()
        guard let ffmpegPath = self.ffmpegPath else {
            processingError = "Could not determine path to FFmpeg."
            return
        }

        processingProcess?.executableURL = URL(fileURLWithPath: ffmpegPath)
        processingProcess?.arguments = [
            "-i", video.path,
            "-i", frame.path,
            "-filter_complex", "[0:v]scale=1080:1920[bg];[bg][1:v]overlay=(W-w)/2:(H-h)/2",
            "-c:a", "copy",
            outputURL.path
        ]

        let errorPipe = Pipe()
        processingProcess?.standardError = errorPipe

        do {
            try processingProcess?.run()
            processingProcess?.waitUntilExit()
            isProcessing = false

            if processingProcess?.terminationStatus == 0 {
                self.processedVideoURL = outputURL
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown FFmpeg error"
                self.processingError = "FFmpeg error: \(errorString)"
            }
        } catch {
            isProcessing = false
            self.processingError = "Error running FFmpeg: \(error.localizedDescription)"
        }
    }

    func showSavePanelForProcessedVideo(completion: @escaping (URL?) -> Void) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType.mpeg4Movie]
        savePanel.nameFieldStringValue = "demofy_processed.mp4"
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                completion(url)
            } else {
                completion(nil)
            }
        }
    }

    func reset() {
        isRecording = false
        videoURL = nil
        droppedVideoURL = nil
        processedVideoURL = nil
        isProcessing = false
        processingError = nil
        // Optionally, keep selectedFrameURL if you want the frame to persist between runs
    }
}
