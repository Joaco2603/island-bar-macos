import AppKit
import IslandCore

enum NotchMetrics {
    static func screen() -> NSScreen {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    static func rect(expanded: Bool, titled: Bool = false) -> NSRect {
        let screen = screen()
        let top = screen.frame.maxY
        let notchBottom = notchBottom(on: screen)
        let lip: CGFloat = expanded ? 0 : (titled ? 0 : -6)
        let height: CGFloat = expanded ? 340 : (top - notchBottom) + lip
        let width: CGFloat = expanded ? 520 : notchWidth(on: screen)
        let x = screen.frame.midX - width / 2
        return NSRect(x: x, y: top - height, width: width, height: height)
    }

    static func hitRect(expanded: Bool, titled: Bool = false) -> NSRect {
        var hit = rect(expanded: expanded, titled: titled).union(notchStrip())
        let top = screen().frame.maxY + 2
        if hit.maxY < top { hit.size.height += top - hit.maxY }
        return hit
    }

    private static func notchBottom(on screen: NSScreen) -> CGFloat {
        let left = screen.auxiliaryTopLeftArea ?? .zero
        if left.width > 0 { return left.minY }
        return screen.frame.maxY - max(screen.safeAreaInsets.top, 29)
    }

    private static func notchWidth(on screen: NSScreen) -> CGFloat {
        let left = screen.auxiliaryTopLeftArea ?? .zero
        let right = screen.auxiliaryTopRightArea ?? .zero
        if left.width > 0, right.width > 0 {
            return max(120, right.minX - left.maxX - 8)
        }
        return 156
    }

    private static func notchStrip() -> NSRect {
        let screen = screen()
        let width = notchWidth(on: screen) + 8
        let bottom = notchBottom(on: screen)
        return NSRect(x: screen.frame.midX - width / 2, y: bottom, width: width, height: screen.frame.maxY - bottom)
    }
}

enum IslandPage: String, CaseIterable, Identifiable {
    case agents, music, timer, calendar, weather, system, tray, camera

    var id: String { rawValue }

    var topGap: CGFloat {
        switch self {
        case .timer, .calendar, .weather, .system: 28
        default: 64
        }
    }

    var title: String {
        switch self {
        case .agents: "Agents"
        case .music: "Now Playing"
        case .timer: "Timer"
        case .calendar: "Calendar"
        case .weather: "Weather"
        case .system: "System"
        case .tray: "File Tray"
        case .camera: "Camera"
        }
    }
}

enum IslandLook: String {
    case glass, classic
}

struct MusicState: Equatable {
    var source = ""
    var title = ""
    var artist = ""
    var playing = false
    var elapsed: Double = 0
    var duration: Double = 0
    var art: Data?
}

struct WeatherState: Equatable {
    var place = ""
    var summary = "—"
    var temp = ""
    var high = ""
    var low = ""
    var feels = ""
    var humidity = ""
    var wind = ""
    var visibility = ""
    var hours: [WeatherHour] = []
}
