import UserNotifications

@MainActor enum NotificationCategories {
    private static var registered: [String: UNNotificationCategory] = [:]

    static func register(_ category: UNNotificationCategory) {
        registered[category.identifier] = category
        UNUserNotificationCenter.current().setNotificationCategories(Set(registered.values))
    }
}
