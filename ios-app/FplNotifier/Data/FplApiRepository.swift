import Foundation

final class FplApiRepository {
    typealias DataFetcher = @Sendable (URL) async throws -> Data

    private static let apiURL = URL(string: "https://fantasy.premierleague.com/api/bootstrap-static/")!
    private let fetcher: DataFetcher
    private let decoder: JSONDecoder
    private let isoFormatters: [ISO8601DateFormatter]

    init(fetcher: DataFetcher? = nil) {
        self.fetcher = fetcher ?? FplApiRepository.defaultFetcher
        self.decoder = JSONDecoder()
        self.isoFormatters = [
            {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                return formatter
            }(),
            {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime]
                return formatter
            }()
        ]
    }

    func getUpcomingDeadlines(now: Date = Date()) async throws -> [GameweekDeadline] {
        let data = try await fetcher(Self.apiURL)
        let payload = try decoder.decode(BootstrapStaticResponse.self, from: data)
        return payload.events
            .compactMap { event -> GameweekDeadline? in
                guard let id = event.id, id > 0 else { return nil }
                guard let rawDeadline = event.deadlineTime,
                      let deadline = try? parseDeadline(rawDeadline),
                      deadline > now else { return nil }
                let name = event.name ?? event.event ?? "Gameweek \(id)"
                return GameweekDeadline(eventId: id, name: name, deadline: deadline)
            }
            .sorted { $0.deadline < $1.deadline }
    }

    private func parseDeadline(_ raw: String) throws -> Date {
        for formatter in isoFormatters {
            if let date = formatter.date(from: raw) {
                return date
            }
        }
        if raw.uppercased().hasSuffix("Z") {
            let adjusted = String(raw.dropLast()) + "+00:00"
            for formatter in isoFormatters {
                if let date = formatter.date(from: adjusted) {
                    return date
                }
            }
        }
        throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Unable to parse deadline \(raw)"))
    }

    private static func defaultFetcher(url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return data
    }
}

private struct BootstrapStaticResponse: Decodable {
    let events: [EventPayload]

    struct EventPayload: Decodable {
        let id: Int?
        let name: String?
        let event: String?
        let deadlineTime: String?

        private enum CodingKeys: String, CodingKey {
            case id
            case name
            case event
            case deadlineTime = "deadline_time"
        }
    }
}
