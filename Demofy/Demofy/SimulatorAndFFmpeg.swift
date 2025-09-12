import Foundation

struct SimulatorDevice {
    let name: String
    let id: String
    
    var displayName: String {
        return name
    }
}

final class SimulatorRecorder {
    private var process: Process?
    private var outputURL: URL?

    // Auto-detect running iOS simulators
    func getRunningSimulators() -> [SimulatorDevice] {
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
            var runningDevices: [SimulatorDevice] = []
            let lines = output.components(separatedBy: .newlines)
            
            for line in lines {
                if line.contains("(Booted)") {
                    // Extract device name and ID from line like: "iPhone 15 (12345678-1234-1234-1234-123456789012) (Booted)"
                    if let idRange = line.range(of: "\\([A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}\\)", options: .regularExpression) {
                        let deviceId = String(line[idRange].dropFirst().dropLast()) // Remove parentheses
                        
                        // Extract device name (everything before the UUID)
                        let nameEndIndex = idRange.lowerBound
                        let deviceName = String(line[..<nameEndIndex]).trimmingCharacters(in: .whitespaces)
                        
                        let device = SimulatorDevice(name: deviceName, id: deviceId)
                        runningDevices.append(device)
                    }
                }
            }
            
            return runningDevices
        } catch {
            print("Failed to get running simulators: \(error)")
            return []
        }
    }
    
    // Get the first running simulator or default
    func getDefaultDevice() -> SimulatorDevice? {
        let runningSimulators = getRunningSimulators()
        return runningSimulators.first
    }

    func startRecording(saveTo url: URL, device: SimulatorDevice? = nil) throws {
        stopRecording() // ensure not running
        
        // Use provided device or auto-detect
        let targetDevice = device ?? getDefaultDevice()
        
        guard let targetDevice = targetDevice else {
            throw NSError(domain: "SimulatorRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: "No running iOS simulators found. Please boot a simulator first."])
        }
        
        print("🎥 Starting recording for device: \(targetDevice.displayName) (\(targetDevice.id))")
        
        // Verify the simulator is actually running
        let runningSimulators = getRunningSimulators()
        let runningIds = runningSimulators.map { $0.id }
        if !runningIds.contains(targetDevice.id) {
            let availableNames = runningSimulators.map { $0.displayName }.joined(separator: ", ")
            throw NSError(domain: "SimulatorRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Simulator \(targetDevice.displayName) is not running. Available devices: \(availableNames)"])
        }
        
        // Ensure the directory exists
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        // Remove any existing file
        try? FileManager.default.removeItem(at: url)
        
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        p.arguments = ["simctl", "io", targetDevice.id, "recordVideo", "--codec", "h264", "--force", url.path]

        let err = Pipe()
        let out = Pipe()
        p.standardError = err
        p.standardOutput = out
        
        err.fileHandleForReading.readabilityHandler = { fh in
            if let s = String(data: fh.availableData, encoding: .utf8), !s.isEmpty {
                print("[simctl stderr] \(s.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }
        
        out.fileHandleForReading.readabilityHandler = { fh in
            if let s = String(data: fh.availableData, encoding: .utf8), !s.isEmpty {
                print("[simctl stdout] \(s.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }
        
        outputURL = url
        try p.run()
        process = p
        
        print("🎥 Recording process started with PID: \(p.processIdentifier)")
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
            print("🎬 Waiting for recording file to be written...")
            // Wait a bit more to ensure the file is fully written
            var retries = 0
            while retries < 30 { // Increased from 10 to 30 retries
                if FileManager.default.fileExists(atPath: url.path) {
                    do {
                        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                        if let fileSize = attributes[.size] as? Int, fileSize > 0 {
                            print("✅ Recording file ready: \(url.lastPathComponent) (\(fileSize) bytes)")
                            break
                        } else {
                            print("⏳ File exists but has 0 bytes, waiting... (attempt \(retries + 1)/30)")
                        }
                    } catch {
                        print("⚠️ Error checking file attributes: \(error)")
                    }
                } else {
                    print("⏳ Waiting for file to appear... (attempt \(retries + 1)/30)")
                }
                Thread.sleep(forTimeInterval: 0.2) // Increased from 0.1 to 0.2 seconds
                retries += 1
            }
            
            if retries >= 30 {
                print("❌ Timeout waiting for recording file to be written")
            }
        }
        
        process = nil
        outputURL = nil
    }
}

