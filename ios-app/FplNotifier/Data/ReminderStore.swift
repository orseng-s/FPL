import Foundation

@MainActor
final class ReminderStore: ObservableObject {
    struct SentReminder: Codable, Equatable {
        let eventId: Int
        let deadline: Date
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

    func recordNotification(for gameweek: GameweekDeadline, timezone: TimeZone) {
        let message = "Sent reminder for \(gameweek.name) (GW \(gameweek.eventId)) at \(DeadlineFormatter.format(gameweek, in: timezone))"
        lastNotification = message
        defaults.set(message, forKey: lastKey)
    }

    func clearLastNotification() {
        lastNotification = nil
        defaults.removeObject(forKey: lastKey)
    }
}
