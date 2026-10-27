import AppKit
import IslandCore
import SwiftUI

extension IslandModel {
    func noteBattery(_ percent: Int) {
        if percent < 20 && !batteryAlerted {
            batteryAlerted = true
            push("Battery \(percent)%")
            present(.system, autoClose: true)
        }
        if percent > 30 { batteryAlerted = false }
    }

    func pollClipboard() {
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

    func refreshWeather() {
        Task { weather = await WeatherFetch.load() }
    }

    func refreshMail() {
        Task.detached {
            let raw = Shell.run("/usr/bin/osascript", ["-e", MailRead.script])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let count = Int(raw)
            await MainActor.run {
                if let count, let previous = self.mailUnread, count > previous {
                    self.push("Mail \(count)")
                    self.present(.calendar, autoClose: true)
                    NSSound.beep()
                }
                self.mailUnread = count
            }
        }
    }
}
