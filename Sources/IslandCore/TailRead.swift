import Foundation

struct TailEvent {
    var type: String
    var status: String
    var stop: String
    var text: String
}

enum TailRead {
    static func events(_ tail: String) -> [TailEvent] {
        var out: [TailEvent] = []
        for line in tail.split(separator: "\n", omittingEmptySubsequences: true) {
            let huge = line.count > 400_000
            if huge && !line.contains("task_complete") && !line.contains("turn_ended") { continue }
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            out.append(event(obj))
        }
        return out
    }

    static func safe(_ text: String) -> String? {
        let flat = text.replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if flat.isEmpty { return nil }
        let lower = flat.lowercased()
        if lower.contains("api_key") || lower.contains("sk-") || lower.contains("secret") { return nil }
        if flat.count <= 110 { return flat }
        return String(flat.prefix(109)) + "…"
    }

    private static func event(_ obj: [String: Any]) -> TailEvent {
        if (obj["type"] as? String) == "turn_ended" {
            return TailEvent(type: "turn_ended", status: obj["status"] as? String ?? "success", stop: "", text: "")
        }
        if (obj["type"] as? String) == "event_msg" {
            let payload = obj["payload"] as? [String: Any] ?? [:]
            let name = payload["type"] as? String ?? "event_msg"
            let text = payload["last_agent_message"] as? String ?? ""
            return TailEvent(type: name, status: name == "task_complete" ? "success" : "", stop: "", text: text)
        }
        if let type = obj["type"] as? String {
            let message = obj["message"] as? [String: Any]
            return TailEvent(
                type: type,
                status: "",
                stop: message?["stop_reason"] as? String ?? "",
                text: text(in: message)
            )
        }
        if let role = obj["role"] as? String {
            return TailEvent(type: role, status: "", stop: "", text: text(in: obj["message"] as? [String: Any]))
        }
        return TailEvent(type: "", status: "", stop: "", text: "")
    }

    private static func text(in message: [String: Any]?) -> String {
        guard let message else { return "" }
        if let content = message["content"] as? String { return content }
        guard let parts = message["content"] as? [Any] else { return "" }
        return parts.compactMap { part in
            (part as? [String: Any])?["text"] as? String
        }.joined(separator: " ")
    }
}
