import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    struct UserSettings: Codable {
        var leadHours: Double
        var pollMinutes: Int
        var timezoneId: String
        var notificationsEnabled: Bool
        var draftNotificationsEnabled: Bool = false
    }

    @Published private(set) var userSettings: UserSettings

    private let defaults: UserDefaults
    private let storageKey = "com.example.fplnotifier.settings"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: storageKey),
           let stored = try? decoder.decode(UserSettings.self, from: data) {
            self.userSettings = stored
        } else {
            let fallback = UserSettings(
                leadHours: 2.0,
                pollMinutes: 360,
                timezoneId: TimeZone.current.identifier,
                notificationsEnabled: false,
                draftNotificationsEnabled: false
            )
            self.userSettings = fallback
        }
    }

    func updateLeadHours(_ value: Double) {
        let newValue = max(value, 0.1)
        guard userSettings.leadHours != newValue else { return }
        userSettings.leadHours = newValue
        persist()
    }

    func updatePollMinutes(_ value: Int) {
        let newValue = max(value, 1)
        guard userSettings.pollMinutes != newValue else { return }
        userSettings.pollMinutes = newValue
        persist()
    }

    func updateTimezone(_ identifier: String) {
        guard userSettings.timezoneId != identifier else { return }
        userSettings.timezoneId = identifier
        persist()
    }

    func setNotificationsEnabled(_ enabled: Bool) {
        guard userSettings.notificationsEnabled != enabled else { return }
        userSettings.notificationsEnabled = enabled
        persist()
    }

    func setDraftNotificationsEnabled(_ enabled: Bool) {
        guard userSettings.draftNotificationsEnabled != enabled else { return }
        userSettings.draftNotificationsEnabled = enabled
        persist()
    }

    private func persist() {
        guard let data = try? encoder.encode(userSettings) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
