import SwiftUI
import IslandCore

struct AgentsPage: View {
    @ObservedObject var model: IslandModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let advisor = model.advisor {
                AgentAdvisorCard(advisor: advisor) { model.dismissAdvisor() }
            }
            ForEach(model.agents) { live in
                AgentRow(
                    live: live,
                    plan: model.plan(for: live.kind),
                    hideHeadline: model.advisor?.kind == live.kind
                )
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
}
