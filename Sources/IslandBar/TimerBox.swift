import Foundation

final class TimerBox: ObservableObject {
    enum Mode: String, CaseIterable, Identifiable {
        case focus, breakTime, countdown, stopwatch
        var id: String { rawValue }
        var title: String {
            switch self {
            case .focus: "Focus"
            case .breakTime: "Break"
            case .countdown: "Countdown"
            case .stopwatch: "Stopwatch"
            }
        }
        var length: TimeInterval {
            switch self {
            case .focus: 25 * 60
            case .breakTime: 5 * 60
            case .countdown: 10 * 60
            case .stopwatch: 0
            }
        }
    }

    @Published var mode: Mode = .countdown
    @Published var running = false
    @Published var left: TimeInterval = 0
    @Published var elapsed: TimeInterval = 0
    var onDone: (() -> Void)?
    private var end: Date?
    private var started: Date?

    func select(_ next: Mode) {
        mode = next
        running = false
        left = next.length
        elapsed = 0
    }

    func preset(_ minutes: Int) {
        mode = .countdown
        running = false
        left = TimeInterval(minutes * 60)
        elapsed = 0
    }

    func toggle() {
        if running {
            running = false
            return
        }
        running = true
        if mode == .stopwatch {
            started = Date().addingTimeInterval(-elapsed)
        } else {
            if left <= 0 { left = mode.length }
            end = Date().addingTimeInterval(left)
        }
    }

    func tick() {
        guard running else { return }
        if mode == .stopwatch {
            elapsed = Date().timeIntervalSince(started ?? Date())
            return
        }
        left = max(0, end?.timeIntervalSinceNow ?? left)
        guard left == 0 else { return }
        running = false
        onDone?()
    }
}

enum ClockText {
    static func mmss(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.down)))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
