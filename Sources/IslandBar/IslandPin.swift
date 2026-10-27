import Foundation
import IslandCore

extension IslandModel {
    var isPagePinned: Bool { pinnedPage == page }

    func togglePagePin() {
        if pinnedPage == page {
            pinnedPage = nil
            UserDefaults.standard.removeObject(forKey: "island.pinnedPage")
        } else {
            pinnedPage = page
            UserDefaults.standard.set(page.rawValue, forKey: "island.pinnedPage")
        }
    }

    func openPinnedPageIfNeeded() {
        guard let pinnedPage else { return }
        page = pinnedPage
    }

    func plan(for kind: AgentKind) -> AgentPlan {
        agentPlans.first { $0.kind == kind } ?? .unknown(kind)
    }
}
