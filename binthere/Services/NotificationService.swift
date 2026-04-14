import UserNotifications
import Foundation

enum NotificationService {

    // MARK: - Permission

    static func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func checkPermission() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Due-Back Reminders

    /// Schedule a reminder for when an item is due back
    static func scheduleDueBackReminder(
        itemId: UUID,
        itemName: String,
        checkedOutTo: String,
        dueDate: Date
    ) {
        let content = UNMutableNotificationContent()
        content.title = "Item Due Back"
        content.body = "\(itemName) was due back from \(checkedOutTo)"
        content.sound = .default
        content.userInfo = ["itemId": itemId.uuidString, "type": "due_back"]

        let triggerDate = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: dueDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let request = UNNotificationRequest(
            identifier: "due_back_\(itemId.uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// Schedule a warning reminder 1 day before due date
    static func scheduleDueBackWarning(
        itemId: UUID,
        itemName: String,
        checkedOutTo: String,
        dueDate: Date
    ) {
        guard let warningDate = Calendar.current.date(byAdding: .day, value: -1, to: dueDate),
              warningDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Item Due Tomorrow"
        content.body = "\(itemName) is due back from \(checkedOutTo) tomorrow"
        content.sound = .default
        content.userInfo = ["itemId": itemId.uuidString, "type": "due_warning"]

        let triggerDate = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: warningDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let request = UNNotificationRequest(
            identifier: "due_warning_\(itemId.uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// Schedule a "someone needs this" notification
    static func scheduleReturnRequest(
        itemId: UUID,
        itemName: String,
        requestedBy: String,
        message: String
    ) {
        let content = UNMutableNotificationContent()
        content.title = "Return Requested"
        content.body = "\(requestedBy) needs \(itemName) back"
            + (message.isEmpty ? "" : ": \(message)")
        content.sound = .default
        content.categoryIdentifier = "RETURN_REQUEST"
        content.userInfo = ["itemId": itemId.uuidString, "type": "return_request"]

        // Fire immediately (1 second delay)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: "return_request_\(itemId.uuidString)_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Overdue Check

    /// Schedule daily check for overdue items
    static func scheduleDailyOverdueCheck() {
        let content = UNMutableNotificationContent()
        content.title = "Overdue Items"
        content.body = "You have items that are past their return date"
        content.sound = .default
        content.userInfo = ["type": "overdue_check"]

        // Fire daily at 9 AM
        var dateComponents = DateComponents()
        dateComponents.hour = 9
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: "daily_overdue_check",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Cancel

    static func cancelDueBackReminders(for itemId: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [
                "due_back_\(itemId.uuidString)",
                "due_warning_\(itemId.uuidString)",
            ]
        )
    }

    static func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
