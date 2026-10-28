import SwiftUI

struct SystemPage: View {
    @ObservedObject var model: IslandModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                stat("CPU", percent(model.system.cpu))
                Spacer()
                stat("Memory", percent(model.system.memory))
                Spacer()
                stat("Battery", "\(model.system.battery)%")
            }
            Text(model.system.charging ? "Charging" : "On battery")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.45))
            line("Brightness", model.system.brightness) { editing, value in
                model.holdBrightness = editing
                model.system.brightness = value
                if !editing { model.setBrightness(value) }
            }
            line("Volume", model.system.volume) { editing, value in
                model.holdVolume = editing
                model.system.volume = value
                if !editing { model.setVolume(value) }
            }
            HStack(spacing: 8) {
                chip("Latency \(model.latency)") { model.measureLatency() }
                chip("Bluetooth") { model.refreshDevices(announce: false) }
            }
            if !model.devices.isEmpty {
                Text(model.devices.joined(separator: "   "))
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(2)
            }
            if model.system.address != "—" {
                Text(model.system.address).font(.system(size: 12)).foregroundStyle(.white.opacity(0.4))
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
    }

    private func stat(_ name: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name).font(.system(size: 12)).foregroundStyle(.white.opacity(0.45))
            Text(value).font(.system(size: 24, weight: .medium, design: .rounded))
        }
    }

    private func line(_ name: String, _ value: Double, _ change: @escaping (Bool, Double) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(name).font(.system(size: 12)).foregroundStyle(.white.opacity(0.45))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.18))
                    Capsule().fill(.white).frame(width: max(8, geo.size.width * value / 100))
                }
                .frame(height: 3)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                    change(true, min(100, max(0, drag.location.x / geo.size.width * 100)))
                }.onEnded { drag in
                    change(false, min(100, max(0, drag.location.x / geo.size.width * 100)))
                })
            }
            .frame(height: 16)
        }
    }

    private func chip(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.white.opacity(0.12), in: Capsule())
    }

    private func percent(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }
}
