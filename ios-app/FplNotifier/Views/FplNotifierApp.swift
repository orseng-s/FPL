import SwiftUI

@main
struct FplNotifierApp: App {
    @StateObject private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: dependencies.viewModel)
                .onAppear {
                    dependencies.scheduler.ensureRunningIfNeeded()
                }
        }
    }
}

private final class AppDependencies: ObservableObject {
    let settingsStore: SettingsStore
    let reminderStore: ReminderStore
    let scheduler: DeadlineScheduler
    let viewModel: MainViewModel

    init() {
        let settings = SettingsStore()
        let reminders = ReminderStore()
        let scheduler = DeadlineScheduler(settingsStore: settings, reminderStore: reminders)
        let viewModel = MainViewModel(settingsStore: settings, reminderStore: reminders, scheduler: scheduler)
        self.settingsStore = settings
        self.reminderStore = reminders
        self.scheduler = scheduler
        self.viewModel = viewModel
    }
}
