import XCTest
@testable import IslandCore

final class AgentParseTests: XCTestCase {
    private func now() -> Date { Date(timeIntervalSince1970: 1_700_000_000) }

    func testCursorFinishAdvisesReview() {
        let tail = """
        {"role":"assistant","message":{"content":[{"type":"text","text":"Added the parser and the notch panel."}]}}
        {"type":"turn_ended","status":"success"}
        """
        let live = AgentParse.live(.cursor, input(tail, age: 2, project: "island-bar"))
        XCTAssertEqual(live.phase, .finished)
        XCTAssertEqual(live.status, "success")
        XCTAssertTrue(live.headline.contains("parser"))
        XCTAssertTrue(live.advice.contains("Review"))
    }

    func testCursorErrorAndOldTurn() {
        let error = "{\"type\":\"turn_ended\",\"status\":\"error\"}\n"
        let fresh = AgentParse.live(.cursor, input(error, age: 3, project: "demo"))
        XCTAssertEqual(fresh.status, "error")
        XCTAssertTrue(fresh.advice.contains("error"))
        let old = AgentParse.live(.cursor, input(error, age: 400, project: "demo"))
        XCTAssertEqual(old.phase, .idle)
    }

    func testCursorWorkingWhileTheFileIsFresh() {
        let tail = #"{"role":"assistant","message":{"content":[{"type":"text","text":"Editing the panel."}]}}"#
        let live = AgentParse.live(.cursor, input(tail, age: 4, project: "island-bar"))
        XCTAssertEqual(live.phase, .working)
        XCTAssertEqual(live.advice, "")
    }

    func testCodexTaskComplete() {
        let tail = #"{"type":"event_msg","payload":{"type":"task_complete","last_agent_message":"Shipped the panel."}}"#
        let live = AgentParse.live(.codex, input(tail, age: 5, project: "rustos"))
        XCTAssertEqual(live.phase, .finished)
        XCTAssertEqual(live.headline, "Shipped the panel.")
    }

    func testClaudeEndTurnAndToolUse() {
        let done = #"{"type":"assistant","message":{"stop_reason":"end_turn","content":[{"type":"text","text":"The tests passed."}]}}"#
        let finished = AgentParse.live(.claude, input(done, age: 20, project: "rustos"))
        XCTAssertEqual(finished.phase, .finished)
        XCTAssertEqual(finished.status, "quiet")
        let tool = #"{"type":"assistant","message":{"stop_reason":"tool_use","content":[{"type":"text","text":"Running tests."}]}}"#
        let working = AgentParse.live(.claude, input(tool, age: 40, project: "rustos", running: true))
        XCTAssertEqual(working.phase, .working)
    }

    func testSecretsStayOffTheIsland() {
        let tail = #"{"role":"assistant","message":{"content":[{"type":"text","text":"api_key sk-live-secret"}]}}"# + "\n"
            + #"{"type":"turn_ended","status":"success"}"#
        let live = AgentParse.live(.cursor, input(tail, age: 2, project: "demo"))
        XCTAssertFalse(live.headline.lowercased().contains("sk-"))
    }

    func testBluetoothShowsConnectedBatteryOnly() {
        let raw = """
        {"SPBluetoothDataType":[{"device_connected":[{"WH-1000XM5":{"device_batteryLevelMain":"80%"}}],"device_not_connected":[{"Other Buds":{}}]}]}
        """
        XCTAssertEqual(BluetoothRead.connected(raw), ["WH-1000XM5 80%"])
    }

    func testProcessNamesUseTheExecutable() {
        let listing = "/usr/bin/zsh\n/opt/homebrew/bin/codex\n/Applications/Claude.app/Contents/MacOS/Claude\n"
        XCTAssertEqual(SessionScan.names(in: listing), ["codex"])
    }

    func testWeatherStartsAtTheCurrentHour() {
        let slots: [[String: Any]] = [
            ["time": "0", "tempF": "60", "weatherDesc": [["value": "Clear"]]],
            ["time": "1500", "tempF": "75", "weatherDesc": [["value": "Sunny"]]],
            ["time": "1800", "tempF": "70", "weatherDesc": [["value": "Cloudy"]]],
        ]
        let hours = WeatherHours.upcoming(slots, nowHour: 15)
        XCTAssertEqual(hours.map(\.label), ["Now", "6p"])
        XCTAssertEqual(hours[0].temp, "75°")
        XCTAssertEqual(hours[0].summary, "Sunny")
    }

    func testOctober2026StartsOnThursday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 27))!
        let cells = MonthGrid.cells(on: date, calendar: calendar)
        XCTAssertEqual(cells.firstIndex(of: 1), 4)
        XCTAssertEqual(cells.compactMap { $0 }.count, 31)
        XCTAssertEqual(cells[30], 27)
    }

    func testProjectNameAndScan() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let dir = root.appendingPathComponent(".cursor/projects/Users-a-programming-demo/agent-transcripts/id")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("id.jsonl")
        try "{\"type\":\"turn_ended\",\"status\":\"aborted\"}\n".write(to: file, atomically: true, encoding: .utf8)
        SessionScan.resetCache()
        let lives = SessionScan.snapshot(roots: SessionRoots(home: root), now: Date(), processes: [])
        let cursor = try XCTUnwrap(lives.first { $0.kind == .cursor })
        XCTAssertEqual(cursor.project, "demo")
        XCTAssertEqual(cursor.phase, .finished)
        XCTAssertEqual(cursor.status, "aborted")
        XCTAssertEqual(lives.count, 3)
        let url = URL(fileURLWithPath: "/tmp/projects/-Users-a-programming-rustos/a.jsonl")
        XCTAssertEqual(SessionScan.projectName(url: url, kind: .claude, head: ""), "rustos")
    }

    private func input(_ tail: String, age: TimeInterval, project: String, running: Bool = false) -> ScanInput {
        let moment = now()
        return ScanInput(
            tail: tail,
            modified: moment.addingTimeInterval(-age),
            now: moment,
            processRunning: running,
            project: project
        )
    }
}
