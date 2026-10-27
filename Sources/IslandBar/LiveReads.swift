import Foundation
import IslandCore

enum MusicRead {
    static let script = """
    set resultText to ""
    if application "Music" is running then
      tell application "Music"
        if player state is playing or player state is paused then
          set resultText to "Music || " & (name of current track) & " || " & (artist of current track) & " || " & (player state as text)
        end if
      end tell
    end if
    if resultText is "" and application "Spotify" is running then
      tell application "Spotify"
        if player state is playing or player state is paused then
          set resultText to "Spotify || " & (name of current track) & " || " & (artist of current track) & " || " & (player state as text)
        end if
      end tell
    end if
    return resultText
    """

    static func current() -> MusicState {
        let raw = Shell.run("/usr/bin/osascript", ["-e", script])
        let parts = raw.components(separatedBy: " || ").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard parts.count >= 4 else { return MusicState() }
        return MusicState(source: parts[0], title: parts[1], artist: parts[2], playing: parts[3] == "playing")
    }

    static func control(_ command: String, source: String) {
        let verb = command == "next" ? "next track" : command == "previous" ? "previous track" : "playpause"
        let apps = source == "Spotify" ? ["Spotify"] : source == "Music" ? ["Music"] : ["Music", "Spotify"]
        for app in apps {
            let script = "if application \"\(app)\" is running then tell application \"\(app)\" to \(verb)"
            _ = Shell.run("/usr/bin/osascript", ["-e", script])
        }
    }
}

enum MailRead {
    static let script = """
    if application "Mail" is running then
      tell application "Mail" to return unread count of inbox
    end if
    """
}

enum WeatherFetch {
    static func load() async -> WeatherState {
        guard let url = URL(string: "https://wttr.in/?format=j1") else { return offline }
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.setValue("IslandBar", forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let current = (json["current_condition"] as? [[String: Any]])?.first else { return offline }
        let temp = degree(current["temp_F"] as? String ?? current["temp_C"] as? String)
        let summary = ((current["weatherDesc"] as? [[String: Any]])?.first?["value"] as? String) ?? "Weather"
        let place = ((json["nearest_area"] as? [[String: Any]])?.first?["areaName"] as? [[String: Any]])?.first?["value"] as? String ?? ""
        let day = (json["weather"] as? [[String: Any]])?.first
        let high = degree(day?["maxtempF"] as? String ?? day?["maxtempC"] as? String)
        let low = degree(day?["mintempF"] as? String ?? day?["mintempC"] as? String)
        let feels = degree(current["FeelsLikeF"] as? String ?? current["FeelsLikeC"] as? String)
        let humidity = (current["humidity"] as? String).map { $0 + "%" } ?? ""
        let wind = (current["windspeedMiles"] as? String).map { $0 + " mph" } ?? ""
        let visibility = (current["visibilityMiles"] as? String).map { $0 + " mi" } ?? ""
        let slots = (day?["hourly"] as? [[String: Any]]) ?? []
        let hours = WeatherHours.upcoming(slots, nowHour: Calendar.current.component(.hour, from: Date()))
        return WeatherState(
            place: place, summary: summary, temp: temp, high: high, low: low,
            feels: feels, humidity: humidity, wind: wind, visibility: visibility, hours: hours
        )
    }

    private static func degree(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "" }
        return raw + "°"
    }

    private static var offline: WeatherState { WeatherState(place: "", summary: "Weather is offline", temp: "") }
}
