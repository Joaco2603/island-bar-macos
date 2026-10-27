import AppKit
import SwiftUI

final class NotchPanel: NSPanel {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

final class PanelHost: NSObject {
    let panel: NotchPanel
    let model: IslandModel
    private var statusItem: NSStatusItem?
    private var monitors: [Any] = []

    init(model: IslandModel) {
        self.model = model
        panel = NotchPanel(
            contentRect: NotchMetrics.rect(expanded: model.expanded, active: model.hasActivity),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovable = false
        let host = NSHostingView(rootView: IslandRoot(model: model))
        host.safeAreaRegions = []
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applyFrame),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        let global = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            self?.trackMouse()
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.trackMouse()
            return event
        }
        if let global { monitors.append(global) }
        if let local { monitors.append(local) }
    }

    func show() {
        applyFrame()
        panel.orderFrontRegardless()
    }

    private func trackMouse() {
        let inside = NotchMetrics.hitRect(expanded: model.expanded, active: model.hasActivity)
            .contains(NSEvent.mouseLocation)
        model.setHover(inside)
    }

    func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "capsule", accessibilityDescription: "IslandBar")
        let menu = NSMenu()
        let show = NSMenuItem(title: "Show", action: #selector(showIsland), keyEquivalent: "")
        show.target = self
        let quit = NSMenuItem(title: "Quit IslandBar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(show)
        menu.addItem(quit)
        item.menu = menu
        statusItem = item
    }

    @objc func showIsland() {
        model.pinned = true
        model.present(model.page)
    }

    @objc func applyFrame() {
        let rect = NotchMetrics.rect(expanded: model.expanded, active: model.hasActivity)
        let same = panel.frame.equalTo(rect)
        panel.hasShadow = model.expanded
        guard !same else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().setFrame(rect, display: true)
        }
        panel.orderFrontRegardless()
    }
}
