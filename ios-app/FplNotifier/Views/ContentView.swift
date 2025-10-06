import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: MainViewModel

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Reminders")) {
                    Toggle("Enable reminders", isOn: Binding(
                        get: { viewModel.state.notificationsEnabled },
                        set: { viewModel.onNotificationsToggled($0) }
                    ))
                    Toggle("Enable draft reminder", isOn: Binding(
                        get: { viewModel.state.draftNotificationsEnabled },
                        set: { viewModel.onDraftNotificationsToggled($0) }
                    ))
                    Stepper(value: Binding(
                        get: { viewModel.state.leadHours },
                        set: { viewModel.onLeadHoursChanged($0) }
                    ), in: 0.5...48, step: 0.5) {
                        Text(viewModel.leadHoursDescription)
                    }
                    Stepper(value: Binding(
                        get: { viewModel.state.pollMinutes },
                        set: { viewModel.onPollMinutesChanged($0) }
                    ), in: 5...1440, step: 5) {
                        Text(viewModel.pollMinutesDescription)
                    }
                }

                Section(header: Text("Timezone")) {
                    Picker("Timezone", selection: Binding(
                        get: { viewModel.state.timezoneId },
                        set: { viewModel.onTimezoneChanged($0) }
                    )) {
                        ForEach(viewModel.timezones, id: \.self) { zone in
                            Text(zone).tag(zone)
                        }
                    }
                }

                Section(header: Text("Status")) {
                    Text(viewModel.state.statusText)
                    if let next = viewModel.state.nextNotificationText {
                        Text(next)
                    }
                    if let last = viewModel.state.lastNotification {
                        Text(last)
                    }
                }
            }
            .navigationTitle("FPL Notifier")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let settings = SettingsStore()
        let reminders = ReminderStore()
        let scheduler = DeadlineScheduler(settingsStore: settings, reminderStore: reminders)
        let viewModel = MainViewModel(settingsStore: settings, reminderStore: reminders, scheduler: scheduler)
        ContentView(viewModel: viewModel)
    }
}
