import Foundation

struct GameweekDeadline: Identifiable, Equatable {
    let eventId: Int
    let name: String
    let deadline: Date

    var id: Int { eventId }

    func formattedDeadline(in timeZone: TimeZone) -> String {
        DeadlineFormatter.format(self, in: timeZone)
    }
}

enum DeadlineFormatter {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm z"
        formatter.timeZone = .current
        return formatter
    }()

    static func string(from deadline: Date, timeZone: TimeZone) -> String {
        formatter.timeZone = timeZone
        return formatter.string(from: deadline)
    }

    static func format(_ deadline: GameweekDeadline, in timeZone: TimeZone) -> String {
        string(from: deadline.deadline, timeZone: timeZone)
    }
}
