import Foundation

final class SimulatorRecorder {
    private var process: Process?
    private var outputURL: URL?

    // Auto-detect running iOS simulators
    func getRunningSimulators() -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "list", "devices", "available"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            // Parse for booted devices
            var runningDevices: [String] = []
            let lines = output.components(separatedBy: .newlines)
            
            for line in lines {
                if line.contains("(Booted)") {
                    // Extract device ID from line like: "iPhone 15 (12345678-1234-1234-1234-123456789012) (Booted)"
                    if let range = line.range(of: "\\([A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}\\)", options: .regularExpression) {
                        var deviceId = String(line[range])
                        deviceId = String(deviceId.dropFirst().dropLast()) // Remove parentheses
                        runningDevices.append(deviceId)
                    }
                }
            }
            
            return runningDevices
        } catch {
            print("Failed to get running simulators: \(error)")
            return []
        }
    }
    
    // Get the first running simulator or "booted"
    func getDefaultDevice() -> String {
        let runningSimulators = getRunningSimulators()
        return runningSimulators.first ?? "booted"
    }

    func startRecording(saveTo url: URL, device: String? = nil) throws {
        stopRecording() // ensure not running
        
        // Use provided device or auto-detect
        let targetDevice = device ?? getDefaultDevice()
        print("🎥 Starting recording for device: \(targetDevice)")
        
        // Ensure the directory exists
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        // Remove any existing file
        try? FileManager.default.removeItem(at: url)
        
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        p.arguments = ["simctl", "io", targetDevice, "recordVideo", "--codec", "h264", "--force", url.path]

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

