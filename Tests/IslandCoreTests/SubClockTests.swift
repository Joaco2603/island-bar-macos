import XCTest
@testable import IslandCore

final class SubClockTests: XCTestCase {
    func testCaptionFormatsDaysLeft() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let until = now.addingTimeInterval(3 * 86_400 + 3600)
        let text = SubClock.caption(plan: "plus", until: until, now: now)
        XCTAssertTrue(text.contains("plus"))
        XCTAssertTrue(text.contains("d left"))
    }

    func testCodexAuthFromFixture() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: home.appendingPathComponent(".codex"), withIntermediateDirectories: true)
        let payload: [String: Any] = [
            "https://api.openai.com/auth": [
                "chatgpt_plan_type": "pro",
                "chatgpt_subscription_active_until": "2026-08-01T12:00:00+00:00",
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let token = "aaa." + data.base64EncodedString() + ".bbb"
        let auth: [String: Any] = ["tokens": ["id_token": token]]
        let raw = try JSONSerialization.data(withJSONObject: auth)
        try raw.write(to: home.appendingPathComponent(".codex/auth.json"))
        let now = ISO8601DateFormatter().date(from: "2026-07-01T12:00:00+00:00")!
        let plan = SubClock.plans(home: home, now: now).first { $0.kind == .codex }
        XCTAssertEqual(plan?.plan, "pro")
        XCTAssertTrue(plan?.caption.contains("d left") == true)
    }
}
