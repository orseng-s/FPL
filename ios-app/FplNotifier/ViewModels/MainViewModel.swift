import Combine
import Foundation
import SwiftUI

@MainActor
final class MainViewModel: ObservableObject {
    struct UiState {
        var leadHours: Double
        var pollMinutes: Int
        var timezoneId: String
        var notificationsEnabled: Bool
        var draftNotificationsEnabled: Bool
        var statusText: String
        var nextNotificationText: String?
        var lastNotification: String?
    }

    @Published private(set) var state: UiState
    let timezones: [String]

    private let settingsStore: SettingsStore
    private let reminderStore: ReminderStore
    private let scheduler: DeadlineScheduler
    private var cancellables: Set<AnyCancellable> = []
    private var plannedNotification: DeadlineScheduler.PlannedNotification?
    private let numberFormatter: NumberFormatter

    init(settingsStore: SettingsStore, reminderStore: ReminderStore, scheduler: DeadlineScheduler) {
        self.settingsStore = settingsStore
        self.reminderStore = reminderStore
        self.scheduler = scheduler
        let settings = settingsStore.userSettings
        let status = MainViewModel.statusText(for: settings)
        self.state = UiState(
            leadHours: settings.leadHours,
            pollMinutes: settings.pollMinutes,
            timezoneId: settings.timezoneId,
            notificationsEnabled: settings.notificationsEnabled,
            draftNotificationsEnabled: settings.draftNotificationsEnabled,
            statusText: status,
            nextNotificationText: nil,
            lastNotification: reminderStore.lastNotification
        )
        self.timezones = TimeZone.knownTimeZoneIdentifiers.sorted()
        self.numberFormatter = NumberFormatter()
        self.numberFormatter.maximumFractionDigits = 1
        self.numberFormatter.minimumFractionDigits = 0
        self.numberFormatter.minimumIntegerDigits = 1

        observeStores()
        scheduler.ensureRunningIfNeeded()
    }

    var leadHoursDescription: String {
        let value = state.leadHours
        if let formatted = numberFormatter.string(from: NSNumber(value: value)) {
            return "Lead time: \(formatted) hours"
        }
        return String(format: "Lead time: %.1f hours", value)
    }

    var pollMinutesDescription: String {
        "Polling interval: \(state.pollMinutes) minutes"
    }

    func onLeadHoursChanged(_ value: Double) {
        settingsStore.updateLeadHours(value)
        if hasActiveNotifications {
            scheduler.restart()
        }
    }

    func onPollMinutesChanged(_ value: Int) {
        settingsStore.updatePollMinutes(value)
        if hasActiveNotifications {
            scheduler.restart()
        }
    }

    func onTimezoneChanged(_ identifier: String) {
        settingsStore.updateTimezone(identifier)
        if hasActiveNotifications {
            scheduler.restart()
        }
    }

    func onNotificationsToggled(_ enabled: Bool) {
        if enabled {
            Task { [weak self] in
                guard let self = self else { return }
                let granted = await self.scheduler.requestAuthorizationIfNeeded()
                if granted {
                    self.settingsStore.setNotificationsEnabled(true)
                    self.scheduler.restart()
                } else {
                    self.settingsStore.setNotificationsEnabled(false)
                }
            }
        } else {
            settingsStore.setNotificationsEnabled(false)
            if hasActiveNotifications {
                scheduler.restart()
            } else {
                scheduler.cancel()
                reminderStore.clearLastNotification()
            }
        }
    }

    func onDraftNotificationsToggled(_ enabled: Bool) {
        if enabled {
            Task { [weak self] in
                guard let self = self else { return }
                let granted = await self.scheduler.requestAuthorizationIfNeeded()
                if granted {
                    self.settingsStore.setDraftNotificationsEnabled(true)
                    self.scheduler.restart()
                } else {
                    self.settingsStore.setDraftNotificationsEnabled(false)
                }
            }
        } else {
            settingsStore.setDraftNotificationsEnabled(false)
            if hasActiveNotifications {
                scheduler.restart()
            } else {
                scheduler.cancel()
                reminderStore.clearLastNotification()
            }
        }
    }

    private func observeStores() {
        settingsStore.$userSettings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] settings in
                guard let self = self else { return }
                self.state.leadHours = settings.leadHours
                self.state.pollMinutes = settings.pollMinutes
                self.state.timezoneId = settings.timezoneId
                self.state.notificationsEnabled = settings.notificationsEnabled
                self.state.draftNotificationsEnabled = settings.draftNotificationsEnabled
                self.state.statusText = MainViewModel.statusText(for: settings)
                self.updateNextNotificationText()
            }
            .store(in: &cancellables)

        reminderStore.$lastNotification
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.state.lastNotification = message
            }
            .store(in: &cancellables)

        scheduler.$plannedNotification
            .receive(on: DispatchQueue.main)
            .sink { [weak self] planned in
                guard let self = self else { return }
                self.plannedNotification = planned
                self.updateNextNotificationText()
            }
            .store(in: &cancellables)
    }

    private func updateNextNotificationText() {
        guard let planned = plannedNotification else {
            state.nextNotificationText = nil
            return
        }
        let timezone = TimeZone(identifier: state.timezoneId) ?? .current
        let formatted = DeadlineFormatter.string(from: planned.notifyAt, timeZone: timezone)
        let typePrefix: String
        switch planned.type {
        case .standard:
            typePrefix = "Reminder"
        case .draft:
            typePrefix = "Draft reminder"
        }
        state.nextNotificationText = "\(typePrefix) for \(planned.gameweek.name) (GW \(planned.gameweek.eventId)) at \(formatted)"
    }

    private var hasActiveNotifications: Bool {
        let settings = settingsStore.userSettings
        return settings.notificationsEnabled || settings.draftNotificationsEnabled
    }

    private static func statusText(for settings: SettingsStore.UserSettings) -> String {
        var enabledTypes: [String] = []
        if settings.notificationsEnabled {
            enabledTypes.append("Standard")
        }
        if settings.draftNotificationsEnabled {
            enabledTypes.append("Draft")
        }
        guard !enabledTypes.isEmpty else {
            return "Notifications disabled"
        }
        if enabledTypes.count == 1, let type = enabledTypes.first {
            return "Notifications enabled (\(type))"
        }
        return "Notifications enabled (\(enabledTypes.joined(separator: ", ")))"
    }
}
