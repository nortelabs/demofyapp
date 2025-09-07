import Foundation

final class SimulatorRecorder {
    private var process: Process?
    private var outputURL: URL?

    func startRecording(saveTo url: URL, device: String = "booted") throws {
        stopRecording() // ensure not running
        
        // Ensure the directory exists
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        // Remove any existing file
        try? FileManager.default.removeItem(at: url)
        
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        p.arguments = ["simctl", "io", device, "recordVideo", "--codec", "h264", "--force", url.path]

        let err = Pipe()
        p.standardError = err
        err.fileHandleForReading.readabilityHandler = { fh in
            if let s = String(data: fh.availableData, encoding: .utf8), !s.isEmpty {
                print("[simctl] \(s.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }
        
        outputURL = url
        try p.run()
        process = p
    }

    func stopRecording() {
        // Send SIGINT to gracefully stop the recording
        process?.interrupt()
        
        // Give it a moment to finalize
        if let p = process {
            let timeout: TimeInterval = 2.0
            let startTime = Date()
            while p.isRunning && Date().timeIntervalSince(startTime) < timeout {
                Thread.sleep(forTimeInterval: 0.1)
            }
            
            // If still running, force terminate
            if p.isRunning {
                p.terminate()
            }
        }
        
        // Ensure the file exists and is accessible
        if let url = outputURL {
            // Wait a bit more to ensure the file is fully written
            var retries = 0
            while retries < 10 {
                if FileManager.default.fileExists(atPath: url.path) {
                    do {
                        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                        if let fileSize = attributes[.size] as? Int, fileSize > 0 {
                            // File exists and has content, we're good to go
                            break
                        }
                    } catch {
                        // Error checking file attributes
                    }
                }
                Thread.sleep(forTimeInterval: 0.1)
                retries += 1
            }
        }
        
        process = nil
        outputURL = nil
    }
}

