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
    private var scrollCarry: CGFloat = 0

    init(model: IslandModel) {
        self.model = model
        panel = NotchPanel(
            contentRect: NotchMetrics.rect(expanded: model.expanded, titled: model.fillsNotch),
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
        installNotchGestures()
    }

    private func installNotchGestures() {
        let swipe = NSEvent.addLocalMonitorForEvents(matching: [.swipe]) { [weak self] event in
            guard let self, self.handleSwipe(event) else { return event }
            return nil
        }
        let scrollLocal = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel]) { [weak self] event in
            guard let self else { return event }
            self.handleScroll(event)
            return event
        }
        let scrollGlobal = NSEvent.addGlobalMonitorForEvents(matching: [.scrollWheel]) { [weak self] event in
            self?.handleScroll(event)
        }
        if let swipe { monitors.append(swipe) }
        if let scrollLocal { monitors.append(scrollLocal) }
        if let scrollGlobal { monitors.append(scrollGlobal) }
    }

    private func handleSwipe(_ event: NSEvent) -> Bool {
        guard model.hover, model.expanded else { return false }
        if event.deltaX > 0 {
            model.previous()
            return true
        }
        if event.deltaX < 0 {
            model.next()
            return true
        }
        return false
    }

    private func handleScroll(_ event: NSEvent) {
        guard model.hover, model.expanded else { return }
        let dx = event.hasPreciseScrollingDeltas ? event.scrollingDeltaX : event.deltaX * 10
        let dy = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.deltaY * 10
        guard abs(dx) > abs(dy) else {
            scrollCarry = 0
            return
        }
        scrollCarry += dx
        if scrollCarry > 28 {
            scrollCarry = 0
            model.previous()
        } else if scrollCarry < -28 {
            scrollCarry = 0
            model.next()
        }
        if event.phase == .ended || event.momentumPhase == .ended {
            scrollCarry = 0
        }
    }

    func show() {
        applyFrame()
        panel.orderFrontRegardless()
    }

    private func trackMouse() {
        let inside = NotchMetrics.hitRect(expanded: model.expanded, titled: model.fillsNotch)
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
        model.openPinnedPageIfNeeded()
        model.pinned = true
        model.present(model.page)
    }

    @objc func applyFrame() {
        let rect = NotchMetrics.rect(expanded: model.expanded, titled: model.fillsNotch)
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
