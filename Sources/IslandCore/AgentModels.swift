import Foundation

public enum AgentKind: String, CaseIterable, Equatable {
    case cursor, codex, claude

    public var title: String {
        switch self {
        case .cursor: "Cursor"
        case .codex: "Codex"
        case .claude: "Claude"
        }
    }
}

public enum AgentPhase: String, Equatable {
    case idle, working, finished
}

public struct AgentLive: Equatable, Identifiable {
    public var kind: AgentKind
    public var project: String
    public var phase: AgentPhase
    public var status: String
    public var headline: String
    public var advice: String
    public var stamp: Date

    public var id: String { kind.rawValue }

    public static func idle(_ kind: AgentKind) -> AgentLive {
        AgentLive(
            kind: kind,
            project: "—",
            phase: .idle,
            status: "none",
            headline: "",
            advice: "",
            stamp: .distantPast
        )
    }
}

struct ScanInput {
    var tail: String
    var modified: Date
    var now: Date
    var processRunning: Bool
    var project: String
}

public enum Hue {
    public static func fraction(_ text: String) -> Double {
        let sum = text.utf8.reduce(0) { ($0 + Int($1)) % 360 }
        return Double(sum) / 360
    }
}

enum AdvisorCopy {
    static func text(_ status: String) -> String {
        switch status {
        case "error":
            "It stopped on an error. Read the last step, fix that, then run it again."
        case "aborted":
            "You cancelled this turn. Send a new one only if you still want that work."
        case "success":
            "It finished cleanly. Review the change, then try it once before you trust it."
        default:
            "It went idle. Check what changed, then decide the next step yourself."
        }
    }
}
