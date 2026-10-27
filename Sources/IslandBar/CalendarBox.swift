import EventKit
import Foundation

struct EventLine: Identifiable, Equatable {
    var id: String
    var title: String
    var when: String
    var soon: Bool
    var join: URL?
}

final class CalendarBox: ObservableObject {
    @Published var lines: [EventLine] = []
    @Published var message = ""
    private let store = EKEventStore()
    private var granted = false
    private var alerted: Set<String> = []

    func load() {
        store.requestFullAccessToEvents { [weak self] ok, _ in
            Task { @MainActor in
                guard let self else { return }
                self.granted = ok
                self.message = ok ? "" : "Calendar access is off."
                if ok { self.reload(alert: nil) }
            }
        }
    }

    func refresh(alert: @escaping (String) -> Void) {
        guard granted else { return }
        reload(alert: alert)
    }

    private func reload(alert: ((String) -> Void)?) {
        let start = Date()
        let end = start.addingTimeInterval(36 * 60 * 60)
        let events = store.events(matching: store.predicateForEvents(withStart: start, end: end, calendars: nil))
        lines = events.prefix(4).map { event in
            let when = event.startDate.formatted(date: .omitted, time: .shortened)
            let soon = event.startDate.timeIntervalSinceNow < 600 && event.startDate.timeIntervalSinceNow > -60
            return EventLine(id: event.eventIdentifier ?? UUID().uuidString, title: event.title ?? "Event", when: when, soon: soon, join: link(event))
        }
        message = lines.isEmpty ? "Nothing else today." : ""
        guard let alert else { return }
        for line in lines where line.soon && alerted.insert(line.id).inserted {
            alert("\(line.title) · \(line.when)")
        }
    }

    private func link(_ event: EKEvent) -> URL? {
        if let url = event.url { return url }
        let blob = (event.notes ?? "") + " " + (event.location ?? "")
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let range = NSRange(blob.startIndex..., in: blob)
        return detector.firstMatch(in: blob, options: [], range: range)?.url
    }
}
