import Foundation

enum AgentParse {
    static func live(_ kind: AgentKind, _ input: ScanInput) -> AgentLive {
        let events = TailRead.events(input.tail)
        let last = events.last
        let age = input.now.timeIntervalSince(input.modified)
        let phase = phase(kind, last: last, age: age, running: input.processRunning)
        let status = status(kind, last: last, phase: phase)
        let snippet = events.reversed().compactMap { TailRead.safe($0.text) }.first
        return AgentLive(
            kind: kind,
            project: input.project,
            phase: phase,
            status: status,
            headline: headline(phase, status: status, snippet: snippet),
            advice: phase == .finished ? AdvisorCopy.text(status) : "",
            stamp: input.modified
        )
    }

    private static func phase(
        _ kind: AgentKind,
        last: TailEvent?,
        age: TimeInterval,
        running: Bool
    ) -> AgentPhase {
        switch kind {
        case .cursor:
            if last?.type == "turn_ended" && age < 120 { return .finished }
            if age < 30 { return .working }
            return .idle
        case .codex:
            if last?.type == "task_complete" && age < 120 { return .finished }
            if running && age < 180 && last?.type != "task_complete" { return .working }
            if age < 30 { return .working }
            return .idle
        case .claude:
            if last?.stop == "tool_use" && age < 21_600 && (age < 180 || running) { return .working }
            if last?.type == "user" && age < 180 { return .working }
            if age < 15 { return .working }
            let ended = last?.stop == "end_turn" || last?.stop == "stop_sequence"
            if ended && age < 120 { return .finished }
            return .idle
        }
    }

    private static func status(_ kind: AgentKind, last: TailEvent?, phase: AgentPhase) -> String {
        if phase == .idle { return "none" }
        if phase == .working { return "working" }
        if kind == .cursor, let raw = last?.status, !raw.isEmpty { return raw }
        if kind == .claude { return "quiet" }
        return "success"
    }

    private static func headline(_ phase: AgentPhase, status: String, snippet: String?) -> String {
        if phase == .idle { return "" }
        if let snippet { return snippet }
        if phase == .working { return "Working" }
        return status
    }
}
