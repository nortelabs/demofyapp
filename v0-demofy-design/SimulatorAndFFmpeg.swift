import Foundation

final class SimulatorRecorder {
    private var process: Process?

    func startRecording(saveTo url: URL, device: String = "booted") throws {
        stopRecording() // ensure not running
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
        try p.run()
        process = p
    }

    func stopRecording() {
        process?.terminate()
        process = nil
    }
}

final class FFmpegRunner {
    struct Progress { let seconds: Double; let raw: String }

    func runRaw(
        command: String,
        in directory: URL? = nil,
        onProgress: @escaping (Progress) -> Void,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/zsh")
        p.arguments = ["-lc", command]
        if let d = directory { p.currentDirectoryURL = d }

        let err = Pipe()
        p.standardError = err
        err.fileHandleForReading.readabilityHandler = { fh in
            guard let s = String(data: fh.availableData, encoding: .utf8), !s.isEmpty else { return }
            if let t = Self.parseFFmpegTime(s) {
                onProgress(.init(seconds: t, raw: s))
            } else {
                print("[ffmpeg] \(s.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }
        p.terminationHandler = { proc in
            if proc.terminationStatus == 0 { completion(.success(())) }
            else { completion(.failure(NSError(domain: "ffmpeg", code: Int(proc.terminationStatus)))) }
        }
        do { try p.run() } catch { completion(.failure(error)) }
    }

    private static func parseFFmpegTime(_ s: String) -> Double? {
        guard let r = s.range(of: "time=") else { return nil }
        let tail = s[r.upperBound...]
        guard let field = tail.split(separator: " ").first else { return nil }
        let parts = field.split(separator: ":")
        guard parts.count == 3 else { return nil }
        let h = Double(parts[0]) ?? 0, m = Double(parts[1]) ?? 0, sec = Double(parts[2]) ?? 0
        return h * 3600 + m * 60 + sec
    }
}