import AppKit
import SwiftUI
import IslandCore

enum AgentArt {
    private static let codexSVG = "/Applications/CodexBar.app/Contents/Resources/ProviderIcon-codex.svg"

    static func image(for kind: AgentKind) -> NSImage? {
        if kind == .codex, let svg = NSImage(contentsOfFile: codexSVG) { return svg }
        let bundle = kind.appBundlePath
        if FileManager.default.fileExists(atPath: bundle) {
            return NSWorkspace.shared.icon(forFile: bundle)
        }
        return nil
    }
}

struct AgentIcon: View {
    var kind: AgentKind
    var size: CGFloat = 18

    var body: some View {
        Group {
            if let image = AgentArt.image(for: kind) {
                Image(nsImage: image).resizable().interpolation(.high).scaledToFit()
            } else {
                Image(systemName: "app.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(AgentColor.body(AgentLive.idle(kind)))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .accessibilityLabel(kind.title)
    }
}
