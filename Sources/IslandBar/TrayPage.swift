import AppKit
import SwiftUI

struct TrayPage: View {
    @ObservedObject var model: IslandModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.tray.isEmpty ? "Drop a file here" : "Files")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
            ForEach(model.tray, id: \.self) { url in
                HStack {
                    Text(url.lastPathComponent).lineLimit(1).font(.system(size: 14, weight: .semibold))
                    Spacer(minLength: 8)
                    chip("Show") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                    chip("AirDrop") { share(url) }
                }
            }
            if !model.clips.isEmpty {
                Text("Clipboard")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .padding(.top, 4)
                ForEach(model.clips.prefix(4), id: \.self) { clip in
                    Text(clip)
                        .font(.system(size: 13))
                        .lineLimit(1)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
    }

    private func chip(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.white.opacity(0.12), in: Capsule())
    }

    private func share(_ url: URL) {
        let picker = NSSharingServicePicker(items: [url])
        guard let view = NSApp.keyWindow?.contentView else { return }
        picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
    }
}
