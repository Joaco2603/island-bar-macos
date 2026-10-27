import AppKit
import IslandCore
import SwiftUI

struct CalendarPage: View {
    @ObservedObject var model: IslandModel
    @ObservedObject var calendar: CalendarBox

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(weekday)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(red: 1, green: 0.38, blue: 0.32))
                Text(dayNumber)
                    .font(.system(size: 52, weight: .light, design: .rounded))
                if let mail = model.mailUnread, mail > 0 {
                    Text("\(mail) unread")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                if !calendar.message.isEmpty {
                    Text(calendar.message).font(.system(size: 12)).foregroundStyle(.white.opacity(0.5))
                }
                ForEach(calendar.lines.prefix(3)) { line in
                    event(line)
                }
                Spacer(minLength: 0)
            }
            .frame(width: 180, alignment: .leading)
            month
        }
        .foregroundStyle(.white)
        .onAppear { model.calendar.load() }
    }

    private var weekday: String { stamp("EEE") }
    private var dayNumber: String { String(Calendar.current.component(.day, from: Date())) }
    private var monthName: String { stamp("MMM") }

    private func stamp(_ format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = format
        return formatter.string(from: Date()).uppercased()
    }

    private var month: some View {
        let cells = monthCells()
        let today = Calendar.current.component(.day, from: Date())
        return VStack(alignment: .trailing, spacing: 8) {
            Text(monthName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(red: 1, green: 0.38, blue: 0.32))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 6) {
                ForEach(Array(["S", "M", "T", "W", "T", "F", "S"].enumerated()), id: \.offset) { _, mark in
                    Text(mark).font(.system(size: 10)).foregroundStyle(.white.opacity(0.35))
                }
                ForEach(Array(cells.enumerated()), id: \.offset) { _, number in
                    dayCell(number, today: today)
                }
            }
        }
    }

    private func dayCell(_ number: Int?, today: Int) -> some View {
        ZStack {
            if number == today {
                Circle().fill(.white).frame(width: 22, height: 22)
            }
            Text(number.map(String.init) ?? "")
                .font(.system(size: 11, weight: number == today ? .bold : .regular))
                .foregroundStyle(number == today ? Color.black : Color.white.opacity(number == nil ? 0 : 0.75))
        }
        .frame(height: 18)
    }

    private func event(_ line: EventLine) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(line.title).lineLimit(1).font(.system(size: 12, weight: .semibold))
                Text(line.when).font(.system(size: 10)).foregroundStyle(.white.opacity(0.55))
            }
            Spacer(minLength: 4)
            if let join = line.join {
                Button("Join") { NSWorkspace.shared.open(join) }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue, in: Capsule())
            }
        }
        .padding(8)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(line.join == nil ? Color.green : Color.blue)
                .frame(width: 3)
                .padding(.vertical, 8)
        }
    }

    private func monthCells() -> [Int?] {
        MonthGrid.cells(on: Date())
    }
}
