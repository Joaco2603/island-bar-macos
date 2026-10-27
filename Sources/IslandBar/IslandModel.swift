import SwiftUI
import IslandCore

final class IslandModel: ObservableObject {
    @Published var expanded = false
    @Published var pinned = false
    @Published var page: IslandPage = .agents
    @Published var look: IslandLook
    @Published var agents: [AgentLive] = AgentKind.allCases.map(AgentLive.idle)
    @Published var advisor: AgentLive?
    @Published var music = MusicState()
    @Published var weather = WeatherState()
    @Published var system = SystemState()
    @Published var clips: [String] = []
    @Published var tray: [URL] = []
    @Published var devices: [String] = []
    @Published var activityLog: [String] = []
    @Published var mailUnread: Int?
    @Published var latency = "—"
    @Published var notice: String?
    @Published var holdVolume = false
    @Published var holdBrightness = false

    let timerBox = TimerBox()
    let calendar = CalendarBox()
    var onFrameChange: (() -> Void)?

    var advised: [AgentKind: Date] = [:]
    var hover = false
    var collapseTask: Task<Void, Never>?
    var ticker: Timer?
    var agentBusy = false
    var musicBusy = false
    var lastClipboard = -1
    var batteryAlerted = false
    var seenDevices: Set<String> = []
    var deviceBusy = false
    var ticks = 0

    init() {
        let raw = UserDefaults.standard.string(forKey: "island.look") ?? IslandLook.glass.rawValue
        look = IslandLook(rawValue: raw) ?? .glass
        timerBox.onDone = { [weak self] in
            self?.push("Timer finished")
            self?.present(.timer)
        }
        if ProcessInfo.processInfo.environment["ISLAND_EXPAND"] == "1" {
            expanded = true
            pinned = true
        }
        if let name = ProcessInfo.processInfo.environment["ISLAND_PAGE"], let picked = IslandPage(rawValue: name) {
            page = picked
        }
    }

    func start() {
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        tick()
    }

    var collapsedTitle: String {
        if let notice { return notice }
        if let advisor { return "\(advisor.kind.title) finished" }
        if let live = agents.first(where: { $0.phase == .working }) { return "\(live.kind.title) working" }
        if music.playing, !music.title.isEmpty { return music.title }
        return ""
    }

    var hasActivity: Bool {
        notice != nil || advisor != nil || music.playing || agents.contains { $0.phase == .working }
    }

    var tint: Color {
        if let live = agents.first(where: { $0.phase == .working || $0.phase == .finished }) {
            return AgentColor.body(live)
        }
        if !music.title.isEmpty {
            return Color(hue: Hue.fraction(music.title), saturation: 0.55, brightness: 0.9)
        }
        return .white
    }

    func setHover(_ inside: Bool) {
        guard inside != hover else { return }
        hover = inside
        collapseTask?.cancel()
        if inside {
            expanded = true
            layout()
            return
        }
        collapseTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !self.hover, !self.pinned else { return }
            self.expanded = false
            self.advisor = nil
            self.notice = nil
            self.layout()
        }
    }

    func toggleLook() {
        look = look == .glass ? .classic : .glass
        UserDefaults.standard.set(look.rawValue, forKey: "island.look")
    }

    func next() { step(1) }
    func previous() { step(-1) }

    func collapse() {
        hover = false
        pinned = false
        advisor = nil
        notice = nil
        expanded = false
        collapseTask?.cancel()
        layout()
    }

    func dismissAdvisor() {
        advisor = nil
        pinned = false
        if !hover { expanded = false }
        layout()
    }

    func flash(_ text: String) {
        notice = text
        expanded = true
        layout()
        collapseTask?.cancel()
        collapseTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            guard !self.hover, !self.pinned else { return }
            self.expanded = false
            self.notice = nil
            self.layout()
        }
    }

    func present(_ next: IslandPage) {
        page = next
        expanded = true
        layout()
    }

    func push(_ line: String) {
        activityLog.insert(line, at: 0)
        if activityLog.count > 6 { activityLog.removeLast() }
    }

    func addTray(_ url: URL) {
        tray.removeAll { $0 == url }
        tray.insert(url, at: 0)
        if tray.count > 6 { tray.removeLast() }
        present(.tray)
    }

    func layout() { onFrameChange?() }

    private func step(_ delta: Int) {
        let pages = IslandPage.allCases
        guard let index = pages.firstIndex(of: page) else { return }
        page = pages[(index + delta + pages.count) % pages.count]
    }
}
