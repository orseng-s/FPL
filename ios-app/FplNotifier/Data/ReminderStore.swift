import Foundation

@MainActor
final class ReminderStore: ObservableObject {
    struct SentReminder: Codable, Equatable {
        enum ReminderType: String, Codable {
            case standard
            case draft
        }

        let eventId: Int
        let deadline: Date
        let type: ReminderType

        init(eventId: Int, deadline: Date, type: ReminderType) {
            self.eventId = eventId
            self.deadline = deadline
            self.type = type
        }

        private enum CodingKeys: String, CodingKey {
            case eventId
            case deadline
            case type
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            eventId = try container.decode(Int.self, forKey: .eventId)
            deadline = try container.decode(Date.self, forKey: .deadline)
            type = try container.decodeIfPresent(ReminderType.self, forKey: .type) ?? .standard
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(eventId, forKey: .eventId)
            try container.encode(deadline, forKey: .deadline)
            try container.encode(type, forKey: .type)
        }
    }

    @Published private(set) var lastNotification: String?

    private let defaults: UserDefaults
    private let sentKey = "com.example.fplnotifier.sentReminders"
    private let lastKey = "com.example.fplnotifier.lastNotification"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var cachedReminders: [SentReminder]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: sentKey),
           let reminders = try? decoder.decode([SentReminder].self, from: data) {
            cachedReminders = reminders
        } else {
            cachedReminders = []
        }
        lastNotification = defaults.string(forKey: lastKey)
    }

    var sentReminders: [SentReminder] {
        cachedReminders
    }

    func saveSentReminders(_ reminders: [SentReminder]) {
        cachedReminders = reminders
        if reminders.isEmpty {
            defaults.removeObject(forKey: sentKey)
        } else if let data = try? encoder.encode(reminders) {
            defaults.set(data, forKey: sentKey)
        }
    }

    func prune(reminders: [SentReminder], now: Date, pollInterval: TimeInterval) -> [SentReminder] {
        reminders.filter { reminder in
            now < reminder.deadline.addingTimeInterval(pollInterval)
        }
    }

    func recordNotification(for gameweek: GameweekDeadline, type: SentReminder.ReminderType, timezone: TimeZone) {
        let prefix: String
        switch type {
        case .standard:
            prefix = "Sent reminder"
        case .draft:
            prefix = "Sent draft reminder"
        }
        let message = "\(prefix) for \(gameweek.name) (GW \(gameweek.eventId)) at \(DeadlineFormatter.format(gameweek, in: timezone))"
        lastNotification = message
        defaults.set(message, forKey: lastKey)
    }

    func clearLastNotification() {
        lastNotification = nil
        defaults.removeObject(forKey: lastKey)
    }
}
