import Foundation
import UserNotifications

enum NotificationHelper {
    static func requestAuthorizationIfNeeded(center: UNUserNotificationCenter = .current()) async -> Bool {
        let settings = await withCheckedContinuation { continuation in
            center.getNotificationSettings { notificationSettings in
                continuation.resume(returning: notificationSettings)
            }
        }
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                return try await withCheckedThrowingContinuation { continuation in
                    center.requestAuthorization(options: [.alert, .sound]) { granted, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: granted)
                        }
                    }
                }
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }

    static func sendNotification(
        for gameweek: GameweekDeadline,
        leadTime: TimeInterval,
        timezone: TimeZone,
        center: UNUserNotificationCenter = .current()
    ) async {
        let content = UNMutableNotificationContent()
        let leadDescription = formatLeadTime(leadTime)
        content.title = "FPL deadline in \(leadDescription)"
        content.body = "\(gameweek.name) (GW \(gameweek.eventId)) deadline at \(DeadlineFormatter.format(gameweek, in: timezone))"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "fpl_deadline_\(gameweek.eventId)",
            content: content,
            trigger: nil
        )

        _ = try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private static func formatLeadTime(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(abs(interval))
        if totalSeconds < 60 {
            return secondsDescription(totalSeconds)
        }
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        var parts: [String] = []
        if hours > 0 {
            parts.append(hours == 1 ? "1 hour" : "\(hours) hours")
        }
        if remainingMinutes > 0 {
            parts.append(remainingMinutes == 1 ? "1 minute" : "\(remainingMinutes) minutes")
        }
        if seconds > 0 && hours == 0 {
            parts.append(secondsDescription(seconds))
        }
        return parts.joined(separator: " and ")
    }

    private static func secondsDescription(_ seconds: Int) -> String {
        return seconds == 1 ? "1 second" : "\(seconds) seconds"
    }
}
