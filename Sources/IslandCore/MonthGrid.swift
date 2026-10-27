import Foundation

public enum MonthGrid {
    public static func cells(on date: Date, calendar: Calendar = .current) -> [Int?] {
        guard let range = calendar.range(of: .day, in: .month, for: date),
              let first = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) else { return [] }
        let pad = calendar.component(.weekday, from: first) - 1
        return Array(repeating: nil, count: pad) + range.map { Optional($0) }
    }
}
