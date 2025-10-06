import Foundation

@MainActor
final class DeadlineScheduler: ObservableObject {
    struct PlannedNotification: Equatable {
        let notifyAt: Date
        let gameweek: GameweekDeadline
        let type: ReminderStore.SentReminder.ReminderType
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
        let settings = settingsStore.userSettings
        if settings.notificationsEnabled || settings.draftNotificationsEnabled {
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
        if !settings.notificationsEnabled && !settings.draftNotificationsEnabled {
            reminderStore.clearLastNotification()
            plannedNotification = nil
            return nil
        }

        let now = dateProvider()
        let pollInterval = max(TimeInterval(settings.pollMinutes * 60), 60)
        let leadInterval = max(settings.leadHours, 0.1) * 3600
        let draftInterval: TimeInterval = 24 * 3600
        let timezone = TimeZone(identifier: settings.timezoneId) ?? .current

        var sent = reminderStore.sentReminders
        sent = reminderStore.prune(reminders: sent, now: now, pollInterval: pollInterval)

        do {
            let deadlines = try await apiRepository.getUpcomingDeadlines(now: now)
            reminderStore.saveSentReminders(sent)
            struct Candidate {
                let notifyAt: Date
                let gameweek: GameweekDeadline
                let type: ReminderStore.SentReminder.ReminderType
                let leadTime: TimeInterval
            }

            let candidates: [Candidate] = deadlines.flatMap { gameweek -> [Candidate] in
                var results: [Candidate] = []
                if settings.notificationsEnabled {
                    results.append(
                        Candidate(
                            notifyAt: gameweek.deadline.addingTimeInterval(-leadInterval),
                            gameweek: gameweek,
                            type: .standard,
                            leadTime: leadInterval
                        )
                    )
                }
                if settings.draftNotificationsEnabled {
                    results.append(
                        Candidate(
                            notifyAt: gameweek.deadline.addingTimeInterval(-draftInterval),
                            gameweek: gameweek,
                            type: .draft,
                            leadTime: draftInterval
                        )
                    )
                }
                return results
            }.sorted { lhs, rhs in
                lhs.notifyAt < rhs.notifyAt
            }

            guard !candidates.isEmpty else {
                plannedNotification = nil
                reminderStore.saveSentReminders(sent)
                return pollInterval
            }

            for candidate in candidates {
                let alreadySent = sent.contains { reminder in
                    reminder.eventId == candidate.gameweek.eventId && reminder.type == candidate.type
                }
                if candidate.notifyAt <= now {
                    if !alreadySent {
                        plannedNotification = nil
                        await NotificationHelper.sendNotification(
                            for: candidate.gameweek,
                            leadTime: candidate.leadTime,
                            type: candidate.type,
                            timezone: timezone
                        )
                        sent.append(
                            ReminderStore.SentReminder(
                                eventId: candidate.gameweek.eventId,
                                deadline: candidate.gameweek.deadline,
                                type: candidate.type
                            )
                        )
                        reminderStore.saveSentReminders(sent)
                        reminderStore.recordNotification(for: candidate.gameweek, type: candidate.type, timezone: timezone)
                        return 0
                    }
                    continue
                } else if !alreadySent {
                    plannedNotification = PlannedNotification(
                        notifyAt: candidate.notifyAt,
                        gameweek: candidate.gameweek,
                        type: candidate.type
                    )
                    reminderStore.saveSentReminders(sent)
                    let wait = min(pollInterval, candidate.notifyAt.timeIntervalSince(now))
                    return max(wait, 1)
                }
            }

            plannedNotification = nil
            reminderStore.saveSentReminders(sent)
            return pollInterval
        } catch {
            reminderStore.saveSentReminders(sent)
            return pollInterval
        }
    }
}
