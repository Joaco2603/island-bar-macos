import SwiftUI

struct TimerPage: View {
    @ObservedObject var box: TimerBox
    private let chips = [1, 3, 5, 10, 15, 30]

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Label(box.mode == .stopwatch ? "Stopwatch" : "Timer", systemImage: "timer")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Button(box.mode == .stopwatch ? "Timer" : "Stopwatch") {
                    box.select(box.mode == .stopwatch ? .countdown : .stopwatch)
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.white.opacity(0.12), in: Capsule())
            }
            Text(box.mode == .stopwatch ? ClockText.mmss(box.elapsed) : ClockText.mmss(box.left))
                .font(.system(size: 72, weight: .light, design: .rounded))
                .monospacedDigit()
                .onTapGesture { box.toggle() }
            if box.mode != .stopwatch {
                HStack(spacing: 8) {
                    ForEach(chips, id: \.self) { minutes in
                        Button("\(minutes)m") { box.preset(minutes) }
                            .buttonStyle(.plain)
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 46, height: 32)
                            .background(.white.opacity(0.12), in: Capsule())
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
    }
}
