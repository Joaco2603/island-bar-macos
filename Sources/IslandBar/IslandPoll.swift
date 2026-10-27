import AppKit
import SwiftUI
import IslandCore

extension IslandModel {
    func tick() {
        let wasActive = hasActivity
        let wasFilled = fillsNotch
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
        if ticks % 30 == 1 { refreshPlans() }
        refreshMusic()
        if ticks % 30 == 1 { refreshWeather() }
        if ticks % 5 == 1 { refreshVolume() }
        if ticks == 2 { refreshDevices(announce: false) }
        if ticks % 45 == 0 { refreshDevices(announce: true) }
        if ticks % 20 == 1 { refreshMail() }
        if ticks % 20 == 1 {
            calendar.refresh { [weak self] title in
                self?.push(title)
                self?.present(.calendar, autoClose: true)
                NSSound.beep()
            }
        }
        if wasActive != hasActivity || wasFilled != fillsNotch { layout() }
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
        if command == "playpause" { music.playing.toggle() }
        let source = music.source
        Task.detached { MusicRead.control(command, source: source) }
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

    func refreshPlans() {
        guard !planBusy else { return }
        planBusy = true
        let home = FileManager.default.homeDirectoryForCurrentUser
        Task.detached {
            let plans = SubClock.plans(home: home)
            await MainActor.run {
                self.agentPlans = plans
                self.planBusy = false
            }
        }
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
            present(.agents, autoClose: true)
            popped = true
        }
        if !popped && before != hasActivity { layout() }
    }

    private func refreshMusic() {
        if let live = NowPlayingFeed.current() {
            let wasPlaying = music.playing
            if live.title.isEmpty {
                if music.playing {
                    music.playing = false
                    layout()
                }
            } else if music.title != live.title || music.artist != live.artist || music.art == nil {
                music = live
                if wasPlaying != live.playing { layout() }
            } else {
                music.playing = live.playing
                music.elapsed = live.elapsed
                music.duration = live.duration
                music.source = live.source
                if wasPlaying != live.playing { layout() }
            }
            return
        }
        guard !musicBusy else { return }
        musicBusy = true
        Task.detached {
            let scraped = MusicRead.current()
            await MainActor.run {
                if !scraped.title.isEmpty, self.music.title.isEmpty {
                    self.music = scraped
                }
                self.musicBusy = false
            }
        }
    }
}
