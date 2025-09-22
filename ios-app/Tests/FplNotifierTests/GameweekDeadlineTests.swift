import XCTest
@testable import FplNotifier

final class GameweekDeadlineTests: XCTestCase {
    private let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    func testParsesUpcomingDeadlines() async throws {
        let data = try loadFixture()
        let repository = FplApiRepository(fetcher: { _ in data })
        let now = isoFormatter.date(from: "2024-08-01T00:00:00Z")!
        let deadlines = try await repository.getUpcomingDeadlines(now: now)
        XCTAssertEqual(deadlines.count, 3)
        XCTAssertEqual(deadlines.map(\.eventId), [1, 2, 3])
        XCTAssertEqual(deadlines.first?.name, "Gameweek 1")
    }

    func testSkipsPastDeadlines() async throws {
        let data = try loadFixture()
        let repository = FplApiRepository(fetcher: { _ in data })
        let now = isoFormatter.date(from: "2024-08-18T00:00:00Z")!
        let deadlines = try await repository.getUpcomingDeadlines(now: now)
        XCTAssertEqual(deadlines.map(\.eventId), [3])
    }

    private func loadFixture() throws -> Data {
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "bootstrap", withExtension: "json") else {
            throw XCTSkip("Fixture missing")
        }
        return try Data(contentsOf: url)
    }
}
