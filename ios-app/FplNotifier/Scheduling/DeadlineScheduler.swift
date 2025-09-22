import Foundation

@MainActor
final class DeadlineScheduler: ObservableObject {
    struct PlannedNotification: Equatable {
        let notifyAt: Date
        let gameweek: GameweekDeadline
    }

    @Published private(set) var plannedNotification: PlannedNotification?

    private let settingsStore: SettingsStore
    private let reminderStore: ReminderStore
    private let apiRepository: FplApiRepository
    private let dateProvider: () -> Date

    private var workerTask: Task<Void, Never>?

    init(
        settingsStore: SettingsStore,
        reminderStore: ReminderStore,
        apiRepository: FplApiRepository = FplApiRepository(),
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.settingsStore = settingsStore
        self.reminderStore = reminderStore
        self.apiRepository = apiRepository
        self.dateProvider = dateProvider
    }

    func ensureRunningIfNeeded() {
        if settingsStore.userSettings.notificationsEnabled {
            start()
        } else {
            cancel()
        }
    }

    func restart() {
        cancel()
        ensureRunningIfNeeded()
    }

    func cancel() {
        workerTask?.cancel()
        workerTask = nil
        plannedNotification = nil
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        await NotificationHelper.requestAuthorizationIfNeeded()
    }

    private func start() {
        guard workerTask == nil else { return }
        workerTask = Task { [weak self] in
            await self?.loop()
        }
    }

    private func loop() async {
        while let delay = await runCycle(), delay >= 0 {
            if delay == 0 {
                continue
            }
            do {
                try await Task.sleep(nanoseconds: UInt64(max(delay, 1) * 1_000_000_000))
            } catch {
                break
            }
        }
        workerTask = nil
    }

    private func runCycle() async -> TimeInterval? {
        let settings = settingsStore.userSettings
        if !settings.notificationsEnabled {
            reminderStore.clearLastNotification()
            plannedNotification = nil
            return nil
        }

        let now = dateProvider()
        let pollInterval = max(TimeInterval(settings.pollMinutes * 60), 60)
        let leadInterval = max(settings.leadHours, 0.1) * 3600
        let timezone = TimeZone(identifier: settings.timezoneId) ?? .current

        var sent = reminderStore.sentReminders
        sent = reminderStore.prune(reminders: sent, now: now, pollInterval: pollInterval)

        do {
            let deadlines = try await apiRepository.getUpcomingDeadlines(now: now)
            reminderStore.saveSentReminders(sent)
            guard let upcoming = deadlines.first else {
                plannedNotification = nil
                return pollInterval
            }
            let notifyAt = upcoming.deadline.addingTimeInterval(-leadInterval)
            let alreadySent = sent.contains { $0.eventId == upcoming.eventId }
            if notifyAt <= now {
                plannedNotification = nil
                if !alreadySent {
                    await NotificationHelper.sendNotification(for: upcoming, leadTime: leadInterval, timezone: timezone)
                    sent.append(ReminderStore.SentReminder(eventId: upcoming.eventId, deadline: upcoming.deadline))
                    reminderStore.saveSentReminders(sent)
                    reminderStore.recordNotification(for: upcoming, timezone: timezone)
                }
                return pollInterval
            } else {
                plannedNotification = PlannedNotification(notifyAt: notifyAt, gameweek: upcoming)
                reminderStore.saveSentReminders(sent)
                let wait = min(pollInterval, notifyAt.timeIntervalSince(now))
                return max(wait, 1)
            }
        } catch {
            reminderStore.saveSentReminders(sent)
            return pollInterval
        }
    }
}
