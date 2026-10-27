import AppKit
import SwiftUI

struct IslandRoot: View {
    @ObservedObject var model: IslandModel
    @State private var dragOver = false

    var body: some View {
        VStack(spacing: 0) {
            if model.expanded {
                PageRouter(model: model)
                PageDots(model: model)
                    .padding(.top, 8)
            } else {
                collapsed
            }
        }
        .padding(.horizontal, model.expanded ? 18 : 8)
        .padding(.top, model.expanded ? 10 : 0)
        .padding(.bottom, model.expanded ? 10 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(chrome)
        .clipShape(shape)
        .overlay(shape.stroke(.white.opacity(0.18)))
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .onDrop(of: [.fileURL], isTargeted: $dragOver) { providers in
            TrayDrop.take(providers) { model.addTray($0) }
            return true
        }
        .onChange(of: dragOver) { _, over in
            if over { model.present(.tray) }
        }
    }

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: model.expanded ? 22 : 0,
            bottomLeadingRadius: model.expanded ? 22 : 12,
            bottomTrailingRadius: model.expanded ? 22 : 12,
            topTrailingRadius: model.expanded ? 22 : 0,
            style: .continuous
        )
    }

    private var collapsed: some View {
        Group {
            if model.collapsedTitle.isEmpty {
                Color.clear.frame(height: 4)
            } else {
                HStack(spacing: 8) {
                    if model.music.playing, !model.collapsedTitle.contains(":") {
                        Circle().fill(model.tint).frame(width: 8, height: 8)
                    }
                    if let advisor = model.advisor {
                        AgentIcon(kind: advisor.kind, size: 16)
                        PhaseDot(phase: advisor.phase, status: advisor.status)
                    } else if let live = model.agents.first(where: { $0.phase == .working }) {
                        AgentIcon(kind: live.kind, size: 16)
                        PhaseDot(phase: live.phase, status: live.status)
                    }
                    Text(model.collapsedTitle)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var chrome: some View {
        let warm = model.page == .music && model.expanded
        return ZStack {
            shape.fill(Color(red: 0.07, green: 0.07, blue: 0.08))
            if warm {
                shape.fill(model.tint.opacity(0.28))
            }
            if model.look == .glass {
                shape.fill(.ultraThinMaterial)
                shape.fill(Color.black.opacity(0.55))
            }
        }
    }
}

struct PageDots: View {
    @ObservedObject var model: IslandModel

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(IslandPage.allCases) { page in
                    Button { model.page = page } label: {
                        Capsule()
                            .fill(page == model.page ? Color.white : Color.white.opacity(0.28))
                            .frame(width: page == model.page ? 16 : 5, height: 5)
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(page.title)
                }
            }
            Button { model.togglePagePin() } label: {
                Image(systemName: model.isPagePinned ? "pin.fill" : "pin")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(model.isPagePinned ? Color.white : Color.white.opacity(0.45))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(model.isPagePinned ? "Unpin page" : "Pin page")
        }
    }
}

enum TrayDrop {
    static func take(_ providers: [NSItemProvider], done: @escaping (URL) -> Void) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                guard let url = url(from: item) else { return }
                DispatchQueue.main.async { done(url) }
            }
        }
    }

    private static func url(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL { return url }
        if let data = item as? Data { return URL(dataRepresentation: data, relativeTo: nil) }
        return nil
    }
}
