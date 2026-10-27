import SwiftUI
import IslandCore

enum AgentColor {
    static func body(_ live: AgentLive) -> Color {
        if live.status == "error" || live.status == "aborted" { return .red }
        switch live.kind {
        case .cursor: return Color(red: 0.35, green: 0.85, blue: 0.55)
        case .codex: return Color(red: 0.95, green: 0.62, blue: 0.28)
        case .claude: return Color(red: 0.72, green: 0.58, blue: 0.95)
        }
    }
}

struct PhaseDot: View {
    var phase: AgentPhase
    var status: String
    @State private var dim = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .opacity(phase == .working && dim ? 0.3 : 1)
            .onAppear { pulse() }
            .onChange(of: phase) { _, _ in pulse() }
    }

    private var color: Color {
        if status == "error" || status == "aborted" { return .red }
        switch phase {
        case .working: return .green
        case .finished: return .blue
        case .idle: return .gray.opacity(0.7)
        }
    }

    private func pulse() {
        guard phase == .working else {
            dim = false
            return
        }
        withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { dim = true }
    }
}
