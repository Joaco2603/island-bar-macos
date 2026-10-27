import SwiftUI
import IslandCore

struct AgentsPage: View {
    @ObservedObject var model: IslandModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let advisor = model.advisor { card(advisor) }
            ForEach(model.agents) { live in
                row(live)
            }
            if !model.activityLog.isEmpty {
                Text(model.activityLog.joined(separator: "  ·  "))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
    }

    private func card(_ advisor: AgentLive) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(advisor.kind.title) finished · \(advisor.project)")
                .font(.system(size: 12, weight: .semibold))
            if !advisor.headline.isEmpty {
                Text(advisor.headline).font(.system(size: 12)).lineLimit(2)
            }
            Text(advisor.advice).font(.system(size: 11)).foregroundStyle(.secondary)
            Button("Dismiss") { model.dismissAdvisor() }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.white.opacity(0.12), in: Capsule())
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private func row(_ live: AgentLive) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                PhaseDot(phase: live.phase, status: live.status)
                Text(live.kind.title).frame(width: 58, alignment: .leading)
                Text(live.phase.rawValue).foregroundStyle(.secondary).frame(width: 68, alignment: .leading)
                Text(live.project).lineLimit(1)
                Spacer(minLength: 0)
            }
            if live.phase != .idle, !live.headline.isEmpty, model.advisor?.kind != live.kind {
                Text(live.headline)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.leading, 16)
            }
        }
        .font(.system(size: 12, weight: .medium))
    }
}
