import AppKit
import SwiftUI
import IslandCore

extension IslandModel {
    func tick() {
        ticks += 1
        timerBox.tick()
        if music.playing {
            music.elapsed += 1
            if music.duration > 0 { music.elapsed = min(music.elapsed, music.duration) }
        }
        let keptVolume = system.volume
        let keptBrightness = system.brightness
        system = SystemPoll.sample(previous: system)
        if let level = DisplayBrightness.read() { system.brightness = level }
        if holdVolume { system.volume = keptVolume }
        if holdBrightness { system.brightness = keptBrightness }
        noteBattery(system.battery)
        pollClipboard()
        if ticks % 2 == 1 { refreshAgents() }
        if ticks % 4 == 1 { refreshMusic() }
        if ticks % 30 == 1 { refreshWeather() }
        if ticks % 5 == 1 { refreshVolume() }
        if ticks == 2 { refreshDevices(announce: false) }
        if ticks % 45 == 0 { refreshDevices(announce: true) }
        if ticks % 20 == 1 { refreshMail() }
        if ticks % 20 == 1 { calendar.refresh { [weak self] title in self?.push(title) } }
    }

    func refreshVolume() {
        Task.detached {
            let value = SystemPoll.volume()
            await MainActor.run {
                if let value, !self.holdVolume { self.system.volume = value }
            }
        }
    }

    func setBrightness(_ value: Double) {
        system.brightness = value
        DisplayBrightness.write(value)
    }

    func setVolume(_ value: Double) {
        system.volume = value
        let rounded = Int(value)
        Task.detached {
            _ = Shell.run("/usr/bin/osascript", ["-e", "set volume output volume \(rounded)"])
        }
    }

    func measureLatency() {
        Task {
            let start = Date()
            guard let url = URL(string: "https://cp.cloudflare.com/generate_204") else { return }
            _ = try? await URLSession.shared.data(from: url)
            latency = "\(Int(Date().timeIntervalSince(start) * 1000)) ms"
        }
    }

    func seek(_ seconds: Double) {
        music.elapsed = seconds
        SystemNowPlaying.seek(seconds)
    }

    func musicCommand(_ command: String) {
        let code: UInt32 = command == "next" ? 4 : command == "previous" ? 5 : 2
        SystemNowPlaying.send(code)
        let source = music.source
        Task.detached {
            MusicRead.control(command, source: source)
            try? await Task.sleep(nanoseconds: 250_000_000)
            let next = await SystemNowPlaying.read() ?? MusicRead.current()
            await MainActor.run { self.music = next }
        }
    }

    func refreshDevices(announce: Bool) {
        guard !deviceBusy else { return }
        deviceBusy = true
        Task.detached {
            let raw = Shell.run("/usr/sbin/system_profiler", ["SPBluetoothDataType", "-json"])
            let names = BluetoothRead.connected(raw)
            await MainActor.run {
                self.deviceBusy = false
                let fresh = names.filter { !self.seenDevices.contains($0) }
                if announce, let first = fresh.first, !self.seenDevices.isEmpty {
                    self.push(first)
                    self.page = .system
                    self.flash(first)
                }
                if !names.isEmpty || announce || !self.seenDevices.isEmpty {
                    self.seenDevices = Set(names)
                }
                self.devices = names.isEmpty ? ["No connected device"] : names
            }
        }
    }

    private func noteBattery(_ percent: Int) {
        if percent < 20 && !batteryAlerted {
            batteryAlerted = true
            push("Battery \(percent)%")
            present(.system)
        }
        if percent > 30 { batteryAlerted = false }
    }

    private func pollClipboard() {
        let board = NSPasteboard.general
        guard board.changeCount != lastClipboard else { return }
        let first = lastClipboard == -1
        lastClipboard = board.changeCount
        guard !first, let text = board.string(forType: .string), !text.isEmpty else { return }
        let clip = String(text.prefix(180))
        clips.removeAll { $0 == clip }
        clips.insert(clip, at: 0)
        if clips.count > 8 { clips.removeLast() }
    }

    private func refreshAgents() {
        guard !agentBusy else { return }
        agentBusy = true
        let home = FileManager.default.homeDirectoryForCurrentUser
        Task.detached {
            let lives = SessionScan.snapshot(home: home)
            await MainActor.run {
                self.apply(lives)
                self.agentBusy = false
            }
        }
    }

    private func apply(_ lives: [AgentLive]) {
        let before = hasActivity
        agents = lives
        var popped = false
        for live in lives where live.phase == .finished && advised[live.kind] != live.stamp {
            advised[live.kind] = live.stamp
            advisor = live
            push("\(live.kind.title) finished · \(live.project)")
            present(.agents)
            popped = true
        }
        if !popped && before != hasActivity { layout() }
    }

    private func refreshMusic() {
        guard !musicBusy else { return }
        musicBusy = true
        Task.detached {
            let next = await SystemNowPlaying.read() ?? MusicRead.current()
            await MainActor.run {
                let wasPlaying = self.music.playing
                self.music = next
                self.musicBusy = false
                if wasPlaying != next.playing { self.layout() }
            }
        }
    }

    private func refreshWeather() {
        Task {
            weather = await WeatherFetch.load()
        }
    }

    private func refreshMail() {
        Task.detached {
            let raw = Shell.run("/usr/bin/osascript", ["-e", MailRead.script])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let count = Int(raw)
            await MainActor.run { self.mailUnread = count }
        }
    }
}
