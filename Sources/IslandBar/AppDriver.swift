import AppKit
import SwiftUI
import IslandCore

@main
final class AppDriver: NSObject, NSApplicationDelegate {
    let model = IslandModel()
    var host: PanelHost?

    static func main() {
        if CommandLine.arguments.contains("--check") {
            Check.run()
            return
        }
        if CommandLine.arguments.contains("--shot") {
            let app = NSApplication.shared
            DispatchQueue.main.async { Check.shot() }
            app.run()
            return
        }
        let app = NSApplication.shared
        let driver = AppDriver()
        app.setActivationPolicy(.accessory)
        app.delegate = driver
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let host = PanelHost(model: model)
        self.host = host
        model.onFrameChange = { [weak host] in host?.applyFrame() }
        host.installStatusItem()
        host.show()
        model.start()
    }
}

enum Check {
    static func run() {
        let lives = SessionScan.snapshot(home: FileManager.default.homeDirectoryForCurrentUser)
        for live in lives {
            print("\(live.kind.rawValue) \(live.phase.rawValue) \(live.project) \(live.status)")
        }
        fflush(stdout)
        _ = NSApplication.shared
        let rect = NotchMetrics.rect(expanded: false, active: false)
        let inset = NotchMetrics.screen().safeAreaInsets.top
        print(String(format: "frame %.0f %.0f %.0f %.0f inset %.0f", rect.origin.x, rect.origin.y, rect.width, rect.height, inset))
    }

    @MainActor
    static func shot() {
        _ = NSApplication.shared
        let model = IslandModel()
        model.expanded = true
        model.pinned = true
        model.agents = SessionScan.snapshot(home: FileManager.default.homeDirectoryForCurrentUser)
        let rect = NotchMetrics.rect(expanded: true, active: false)
        let renderer = ImageRenderer(content: IslandRoot(model: model).frame(width: rect.width, height: rect.height))
        renderer.scale = 2
        let url = URL(fileURLWithPath: "/tmp/island-shot.png")
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            fputs("shot failed\n", stderr)
            exit(1)
        }
        try? png.write(to: url)
        print(url.path)
        exit(0)
    }
}
