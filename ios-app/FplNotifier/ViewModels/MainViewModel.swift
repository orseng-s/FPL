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
        let status = MainViewModel.statusText(enabled: settings.notificationsEnabled)
        self.state = UiState(
            leadHours: settings.leadHours,
            pollMinutes: settings.pollMinutes,
            timezoneId: settings.timezoneId,
            notificationsEnabled: settings.notificationsEnabled,
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
        if settingsStore.userSettings.notificationsEnabled {
            scheduler.restart()
        }
    }

    func onPollMinutesChanged(_ value: Int) {
        settingsStore.updatePollMinutes(value)
        if settingsStore.userSettings.notificationsEnabled {
            scheduler.restart()
        }
    }

    func onTimezoneChanged(_ identifier: String) {
        settingsStore.updateTimezone(identifier)
        if settingsStore.userSettings.notificationsEnabled {
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
            scheduler.cancel()
            reminderStore.clearLastNotification()
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
                self.state.statusText = MainViewModel.statusText(enabled: settings.notificationsEnabled)
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
        state.nextNotificationText = "Reminder for \(planned.gameweek.name) (GW \(planned.gameweek.eventId)) at \(formatted)"
    }

    private static func statusText(enabled: Bool) -> String {
        enabled ? "Notifications enabled" : "Notifications disabled"
    }
}
