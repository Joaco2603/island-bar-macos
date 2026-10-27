import Foundation

enum NowPlayingFeed {
    private static var process: Process?
    private static var buffer = ""
    private static let lock = NSLock()
    private static var latest: MusicState?
    private static var sawTrack = false

    static func start() {
        guard process == nil else { return }
        let script = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Scripts/now_playing_helper.swift")
        guard FileManager.default.fileExists(atPath: script.path) else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["swift", script.path]
        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        errors.fileHandleForReading.readabilityHandler = { handle in
            _ = handle.availableData
        }
        guard (try? process.run()) != nil else { return }
        self.process = process
        output.fileHandleForReading.readabilityHandler = { handle in
            let chunk = String(decoding: handle.availableData, as: UTF8.self)
            guard !chunk.isEmpty else { return }
            lock.lock()
            buffer += chunk
            while let newline = buffer.firstIndex(of: "\n") {
                let line = String(buffer[..<newline])
                buffer = String(buffer[buffer.index(after: newline)...])
                if let state = parse(line) {
                    latest = state
                    if !state.title.isEmpty { sawTrack = true }
                }
            }
            lock.unlock()
        }
    }

    static func current() -> MusicState? {
        lock.lock()
        defer { lock.unlock() }
        guard sawTrack else { return nil }
        return latest
    }

    private static func parse(_ line: String) -> MusicState? {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let art = (json["art"] as? String).flatMap { Data(base64Encoded: $0) }
        return MusicState(
            source: json["source"] as? String ?? "",
            title: json["title"] as? String ?? "",
            artist: json["artist"] as? String ?? "",
            playing: (json["playing"] as? NSNumber)?.boolValue ?? false,
            elapsed: (json["elapsed"] as? NSNumber)?.doubleValue ?? 0,
            duration: (json["duration"] as? NSNumber)?.doubleValue ?? 0,
            art: art
        )
    }
}
