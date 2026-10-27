import SwiftUI
import IslandCore

struct AgentAdvisorCard: View {
    var advisor: AgentLive
    var dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                AgentIcon(kind: advisor.kind)
                Text("finished · \(advisor.project)")
                    .font(.system(size: 12, weight: .semibold))
            }
            if !advisor.headline.isEmpty {
                Text(advisor.headline).font(.system(size: 12)).lineLimit(2)
            }
            Text(advisor.advice).font(.system(size: 11)).foregroundStyle(.secondary)
            Button("Dismiss", action: dismiss)
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
}

struct AgentRow: View {
    var live: AgentLive
    var plan: AgentPlan
    var hideHeadline: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                PhaseDot(phase: live.phase, status: live.status)
                AgentIcon(kind: live.kind)
                Text(live.phase.rawValue)
                    .foregroundStyle(.secondary)
                    .frame(width: 58, alignment: .leading)
                Text(plan.caption)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(plan.caption == "—" ? Color.secondary : Color.white.opacity(0.85))
                    .frame(width: 92, alignment: .leading)
                    .lineLimit(1)
                Text(live.project).lineLimit(1)
                Spacer(minLength: 0)
            }
            if live.phase != .idle, !live.headline.isEmpty, !hideHeadline {
                Text(live.headline)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.leading, 34)
            }
        }
        .font(.system(size: 12, weight: .medium))
    }
}
