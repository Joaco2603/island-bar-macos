import Foundation

public enum SubClock {
    public static func plans(home: URL, now: Date = Date()) -> [AgentPlan] {
        AgentKind.allCases.map { plan(for: $0, home: home, now: now) }
    }

    static func plan(for kind: AgentKind, home: URL, now: Date) -> AgentPlan {
        switch kind {
        case .codex: return codex(home: home, now: now)
        case .claude: return claude(home: home, now: now)
        case .cursor: return cursor(home: home, now: now)
        }
    }

    private static func codex(home: URL, now: Date) -> AgentPlan {
        let url = home.appendingPathComponent(".codex/auth.json")
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = (json["tokens"] as? [String: Any])?["id_token"] as? String,
              let payload = JWTPayload.decode(token) else {
            return .unknown(.codex)
        }
        let auth = payload["https://api.openai.com/auth"] as? [String: Any] ?? payload
        let plan = (auth["chatgpt_plan_type"] as? String) ?? ""
        let until = date(from: auth["chatgpt_subscription_active_until"])
        return AgentPlan(kind: .codex, plan: plan, caption: caption(plan: plan, until: until, now: now))
    }

    private static func claude(home: URL, now: Date) -> AgentPlan {
        let paths = [
            home.appendingPathComponent(".claude/.credentials.json"),
            home.appendingPathComponent(".claude.json"),
        ]
        for url in paths {
            guard let data = try? Data(contentsOf: url),
                  let json = try? JSONSerialization.jsonObject(with: data) else { continue }
            if let hit = SubscriptionDates.first(in: json) {
                return AgentPlan(
                    kind: .claude,
                    plan: hit.plan,
                    caption: caption(plan: hit.plan, until: hit.until, now: now)
                )
            }
        }
        return .unknown(.claude)
    }

    private static func cursor(home: URL, now: Date) -> AgentPlan {
        let storage = home
            .appendingPathComponent("Library/Application Support/Cursor/User/globalStorage/storage.json")
        guard let data = try? Data(contentsOf: storage),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            return .unknown(.cursor)
        }
        if let hit = SubscriptionDates.first(in: json) {
            return AgentPlan(
                kind: .cursor,
                plan: hit.plan,
                caption: caption(plan: hit.plan, until: hit.until, now: now)
            )
        }
        return .unknown(.cursor)
    }

    static func caption(plan: String, until: Date?, now: Date) -> String {
        guard let until else {
            return plan.isEmpty ? "—" : plan
        }
        if until <= now { return plan.isEmpty ? "expired" : "\(plan) · expired" }
        let seconds = until.timeIntervalSince(now)
        let label = remaining(seconds)
        if plan.isEmpty { return label }
        return "\(plan) · \(label)"
    }

    static func remaining(_ seconds: TimeInterval) -> String {
        if seconds < 3600 { return "\(max(1, Int(seconds / 60)))m left" }
        if seconds < 86_400 * 2 { return "\(max(1, Int(seconds / 3600)))h left" }
        return "\(max(1, Int(seconds / 86_400)))d left"
    }

    private static func date(from raw: Any?) -> Date? {
        guard let text = raw as? String, !text.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: text) { return date }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: text)
    }
}

enum JWTPayload {
    static func decode(_ token: String) -> [String: Any]? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var base = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let pad = (4 - base.count % 4) % 4
        base += String(repeating: "=", count: pad)
        guard let data = Data(base64Encoded: base),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json
    }
}

enum SubscriptionDates {
    struct Hit {
        var plan: String
        var until: Date?
    }

    static func first(in root: Any) -> Hit? {
        var best: Hit?
        walk(root) { key, value in
            let lower = key.lowercased()
            guard lower.contains("subscription") || lower.contains("billingcycle") else { return }
            if lower.contains("plan") || lower.contains("type") || lower.contains("membership") {
                if let text = value as? String, !text.isEmpty {
                    best = Hit(plan: text, until: best?.until)
                }
                return
            }
            if let date = parseDate(value) {
                best = Hit(plan: best?.plan ?? "", until: date)
            }
        }
        return best?.until == nil && (best?.plan.isEmpty ?? true) ? nil : best
    }

    private static func walk(_ node: Any, visit: (String, Any) -> Void) {
        if let dict = node as? [String: Any] {
            for (key, value) in dict {
                visit(key, value)
                walk(value, visit: visit)
            }
        } else if let list = node as? [Any] {
            for item in list { walk(item, visit: visit) }
        }
    }

    private static func parseDate(_ value: Any) -> Date? {
        if let text = value as? String, !text.isEmpty {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso.date(from: text) { return date }
            iso.formatOptions = [.withInternetDateTime]
            if let date = iso.date(from: text) { return date }
            let ms = Double(text)
            if let ms, ms > 1_000_000_000_000 { return Date(timeIntervalSince1970: ms / 1000) }
            if let ms, ms > 1_000_000_000 { return Date(timeIntervalSince1970: ms) }
        }
        if let ms = value as? Double, ms > 1_000_000_000 { return Date(timeIntervalSince1970: ms / (ms > 1e12 ? 1000 : 1)) }
        return nil
    }
}
