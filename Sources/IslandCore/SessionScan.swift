import Foundation

struct SessionRoots {
    var cursor: URL
    var codex: URL
    var claude: URL

    init(home: URL) {
        cursor = home.appendingPathComponent(".cursor/projects")
        codex = home.appendingPathComponent(".codex/sessions")
        claude = home.appendingPathComponent(".claude/projects")
    }
}

public enum SessionScan {
    private static var cache: [String: (Date, URL?)] = [:]

    static func resetCache() { cache.removeAll() }

    public static func snapshot(home: URL, now: Date = Date()) -> [AgentLive] {
        let listing = Shell.run("/bin/ps", ["-axo", "command="])
        return snapshot(roots: SessionRoots(home: home), now: now, processes: names(in: listing))
    }

    static func snapshot(roots: SessionRoots, now: Date, processes: Set<String>) -> [AgentLive] {
        [
            one(.cursor, root: roots.cursor, now: now, running: false),
            one(.codex, root: roots.codex, now: now, running: processes.contains("codex")),
            one(.claude, root: roots.claude, now: now, running: processes.contains("claude")),
        ]
    }

    static func names(in listing: String) -> Set<String> {
        var names: Set<String> = []
        for line in listing.split(separator: "\n") {
            let token = line.split(separator: " ").first.map(String.init) ?? ""
            let base = URL(fileURLWithPath: token).lastPathComponent.lowercased()
            let app = line.lowercased().contains(".app/")
            if !app && (base == "claude" || base == "codex") { names.insert(base) }
        }
        return names
    }

    static func projectName(url: URL, kind: AgentKind, head: String) -> String {
        if kind == .codex {
            guard let range = head.range(of: "\"cwd\":\""),
                  let end = head[range.upperBound...].firstIndex(of: "\"") else { return "codex" }
            let path = head[range.upperBound..<end].replacingOccurrences(of: "\\/", with: "/")
            let name = URL(fileURLWithPath: path).lastPathComponent
            return name.isEmpty ? "codex" : name
        }
        let parts = url.pathComponents
        guard let index = parts.lastIndex(of: "projects"), index + 1 < parts.count else { return kind.rawValue }
        let raw = parts[index + 1]
        guard let mark = raw.range(of: "programming-", options: .backwards) else { return raw }
        let name = String(raw[mark.upperBound...])
        return name.isEmpty ? raw : name
    }

    private static func one(_ kind: AgentKind, root: URL, now: Date, running: Bool) -> AgentLive {
        guard let url = newest(kind, root: root, now: now) else { return .idle(kind) }
        let input = ScanInput(
            tail: slice(url, fromEnd: 64_000),
            modified: modified(url),
            now: now,
            processRunning: running,
            project: projectName(url: url, kind: kind, head: kind == .codex ? head(url) : "")
        )
        return AgentParse.live(kind, input)
    }

    private static func newest(_ kind: AgentKind, root: URL, now: Date) -> URL? {
        if let hit = cache[root.path], now.timeIntervalSince(hit.0) < 4 { return hit.1 }
        let found = kind == .codex ? shallow(root, depth: 4) : direct(root, kind)
        cache[root.path] = (now, found)
        return found
    }

    private static func direct(_ root: URL, _ kind: AgentKind) -> URL? {
        let manager = FileManager.default
        guard let projects = try? manager.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        ) else { return nil }
        var best: URL?
        var bestDate = Date.distantPast
        for project in projects {
            let folder = kind == .cursor ? project.appendingPathComponent("agent-transcripts") : project
            guard let children = try? manager.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
            ) else { continue }
            for child in children {
                let named = child.appendingPathComponent(child.lastPathComponent + ".jsonl")
                let candidate = kind == .cursor && manager.fileExists(atPath: named.path) ? named : child
                guard candidate.pathExtension == "jsonl" else { continue }
                let date = modified(candidate)
                if date > bestDate {
                    best = candidate
                    bestDate = date
                }
            }
        }
        return best
    }

    private static func shallow(_ root: URL, depth: Int) -> URL? {
        guard depth >= 0, let children = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }
        var best: URL?
        var bestDate = Date.distantPast
        for child in children {
            let dir = (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let pick = dir ? shallow(child, depth: depth - 1) : (child.pathExtension == "jsonl" ? child : nil)
            guard let pick else { continue }
            let date = modified(pick)
            if date > bestDate {
                best = pick
                bestDate = date
            }
        }
        return best
    }

    private static func modified(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    private static func slice(_ url: URL, fromEnd maxBytes: Int) -> String {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return "" }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        let start = size > UInt64(maxBytes) ? size - UInt64(maxBytes) : 0
        try? handle.seek(toOffset: start)
        return String(decoding: handle.readDataToEndOfFile(), as: UTF8.self)
    }

    private static func head(_ url: URL) -> String {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return "" }
        defer { try? handle.close() }
        return String(decoding: handle.readData(ofLength: 2500), as: UTF8.self)
    }
}

public enum Shell {
    public static func run(_ path: String, _ args: [String]) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = args
        let out = Pipe()
        let err = Pipe()
        task.standardOutput = out
        task.standardError = err
        guard (try? task.run()) != nil else { return "" }
        let drain = DispatchQueue(label: "island.shell")
        drain.async { _ = err.fileHandleForReading.readDataToEndOfFile() }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else { return "" }
        return String(decoding: data, as: UTF8.self)
    }
}
