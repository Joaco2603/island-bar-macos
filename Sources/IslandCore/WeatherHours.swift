import Foundation

public struct WeatherHour: Equatable, Identifiable {
    public var label: String
    public var temp: String
    public var summary: String
    public var id: String { label + temp }

    public init(label: String, temp: String, summary: String = "") {
        self.label = label
        self.temp = temp
        self.summary = summary
    }
}

public enum WeatherHours {
    public static func upcoming(_ slots: [[String: Any]], nowHour: Int) -> [WeatherHour] {
        let parsed: [(Int, WeatherHour)] = slots.compactMap { slot in
            guard let value = slot["tempF"] as? String ?? slot["tempC"] as? String else { return nil }
            let hour = (Int(slot["time"] as? String ?? "") ?? 0) / 100
            let label = hour == 0 ? "12a" : hour < 12 ? "\(hour)a" : hour == 12 ? "12p" : "\(hour - 12)p"
            let summary = ((slot["weatherDesc"] as? [[String: Any]])?.first?["value"] as? String) ?? ""
            return (hour, WeatherHour(label: label, temp: value + "°", summary: summary))
        }
        let later = parsed.filter { $0.0 >= nowHour }
        let chosen = Array((later.isEmpty ? parsed : later).prefix(6))
        return chosen.enumerated().map { index, pair in
            guard index == 0 else { return pair.1 }
            return WeatherHour(label: "Now", temp: pair.1.temp, summary: pair.1.summary)
        }
    }
}
