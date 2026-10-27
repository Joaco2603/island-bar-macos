import SwiftUI

struct WeatherPage: View {
    @ObservedObject var model: IslandModel
    private var weather: WeatherState { model.weather }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: symbol(weather.summary))
                    .font(.system(size: 28))
                    .symbolRenderingMode(.multicolor)
                Text(weather.temp.isEmpty ? "—" : weather.temp)
                    .font(.system(size: 48, weight: .medium, design: .rounded))
                Text(weather.summary)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(red: 0.95, green: 0.62, blue: 0.28))
                Spacer()
            }
            Text(range)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.55))
            if !weather.hours.isEmpty {
                HStack {
                    ForEach(weather.hours) { hour in
                        VStack(spacing: 6) {
                            Text(hour.label).font(.system(size: 11, weight: .semibold))
                            Image(systemName: symbol(weather.summary)).font(.system(size: 14))
                            Text(hour.temp).font(.system(size: 12, weight: .medium, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .foregroundStyle(.white.opacity(0.85))
            }
            HStack {
                if !weather.humidity.isEmpty { meta("humidity.fill", weather.humidity) }
                if !weather.wind.isEmpty { meta("wind", weather.wind) }
                if !weather.visibility.isEmpty { meta("eye.fill", weather.visibility) }
                Spacer()
                if !weather.place.isEmpty {
                    Label(weather.place, systemImage: "location.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var range: String {
        let high = weather.high.isEmpty ? "" : "H:\(weather.high)"
        let low = weather.low.isEmpty ? "" : "L:\(weather.low)"
        let feels = weather.feels.isEmpty ? "" : "Feels \(weather.feels)"
        return [high, low, feels].filter { !$0.isEmpty }.joined(separator: "  ")
    }

    private func meta(_ icon: String, _ text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.75))
            .padding(.trailing, 8)
    }

    private func symbol(_ summary: String) -> String {
        let text = summary.lowercased()
        if text.contains("rain") || text.contains("drizzle") { return "cloud.rain.fill" }
        if text.contains("snow") { return "cloud.snow.fill" }
        if text.contains("cloud") { return "cloud.sun.fill" }
        if text.contains("clear") || text.contains("sun") { return "sun.max.fill" }
        return "cloud.fill"
    }
}
