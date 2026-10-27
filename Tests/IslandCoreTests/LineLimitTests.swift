import XCTest

final class LineLimitTests: XCTestCase {
    func testSourceFilesStayAtOrUnder200Lines() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        for folder in ["Sources", "Tests"] {
            let base = root.appendingPathComponent(folder)
            let names = try FileManager.default.subpathsOfDirectory(atPath: base.path)
            for name in names where name.hasSuffix(".swift") {
                let text = try String(contentsOf: base.appendingPathComponent(name))
                var lines = text.reduce(into: 0) { count, char in
                    if char == "\n" { count += 1 }
                }
                if !text.hasSuffix("\n") { lines += 1 }
                XCTAssertLessThanOrEqual(lines, 200, name)
            }
        }
    }
}
