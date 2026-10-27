import AppKit
import AVKit
import SwiftUI

struct MusicPage: View {
    @ObservedObject var model: IslandModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                art
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.music.title.isEmpty ? "Nothing playing" : model.music.title)
                        .font(.system(size: 22, weight: .semibold))
                        .lineLimit(1)
                    Text(model.music.artist.isEmpty ? model.music.source : model.music.artist)
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Wave(on: model.music.playing, tint: model.tint)
            }
            HStack {
                Text(TrackTime.text(model.music.elapsed))
                    .font(.system(size: 11, design: .rounded)).foregroundStyle(.white.opacity(0.45))
                GeometryReader { geo in
                    let fraction = model.music.duration > 0 ? min(1, model.music.elapsed / model.music.duration) : 0
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.22))
                        Capsule().fill(.white).frame(width: max(0, geo.size.width * fraction))
                        Circle().fill(.white).frame(width: 10, height: 10)
                            .offset(x: max(0, geo.size.width * fraction - 5))
                    }
                    .frame(height: 3)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                        guard model.music.duration > 0, geo.size.width > 0 else { return }
                        let fraction = min(1, max(0, value.location.x / geo.size.width))
                        model.music.elapsed = model.music.duration * fraction
                    }.onEnded { value in
                        guard model.music.duration > 0, geo.size.width > 0 else { return }
                        let fraction = min(1, max(0, value.location.x / geo.size.width))
                        model.seek(model.music.duration * fraction)
                    })
                }
                .frame(height: 14)
                Text(TrackTime.left(model.music.elapsed, model.music.duration))
                    .font(.system(size: 11, design: .rounded)).foregroundStyle(.white.opacity(0.45))
            }
            HStack {
                Spacer()
                transport("backward.end") { model.musicCommand("previous") }
                transport(model.music.playing ? "pause.fill" : "play.fill", big: true) {
                    model.musicCommand("playpause")
                }
                transport("forward.end") { model.musicCommand("next") }
                AirPlayButton().frame(width: 28, height: 22)
                Spacer()
            }
            VolumeLine(level: model.system.volume) { model.setVolume($0) }
        }
    }

    private var art: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(model.tint.opacity(0.85))
            if let art = model.music.art, let image = NSImage(data: art) {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "music.note").font(.title2).foregroundStyle(.white)
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func transport(_ symbol: String, big: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: big ? 28 : 18, weight: .semibold))
                .frame(width: big ? 54 : 36, height: 36)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
    }
}

private struct AirPlayButton: NSViewRepresentable {
    func makeNSView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.isRoutePickerButtonBordered = false
        return picker
    }

    func updateNSView(_ picker: AVRoutePickerView, context: Context) {}
}

private struct TrackTime {
    static func text(_ seconds: Double) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static func left(_ elapsed: Double, _ duration: Double) -> String {
        guard duration > elapsed else { return "—" }
        let total = Int(duration - elapsed)
        return String(format: "-%d:%02d", total / 60, total % 60)
    }
}

private struct VolumeLine: View {
    var level: Double
    var set: (Double) -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.22))
                Capsule().fill(.white).frame(width: geo.size.width * level / 100)
            }
            .frame(height: 3)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onEnded { value in
                let next = min(100, max(0, value.location.x / geo.size.width * 100))
                set(next)
            })
        }
        .frame(height: 18)
    }
}

private struct Wave: View {
    var on: Bool
    var tint: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.18, paused: !on)) { context in
            let step = Int(context.date.timeIntervalSinceReferenceDate / 0.18)
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(barColor(index))
                        .frame(width: 3, height: barHeight(step: step, index: index))
                }
            }
            .frame(height: 22, alignment: .bottom)
        }
    }

    private func barHeight(step: Int, index: Int) -> CGFloat {
        guard on else { return 6 }
        return CGFloat(6 + ((step + index * 2) % 5) * 3)
    }

    private func barColor(_ index: Int) -> Color {
        index == 4 ? Color.white.opacity(0.25) : tint
    }
}
