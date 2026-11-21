import Foundation

enum IntroPolicy {
    static func shows(lastActive: Date?, now: Date) -> Bool {
        guard let lastActive, lastActive <= now else { return true }
        return now.timeIntervalSince(lastActive) > AppConstants.introSkipInterval
    }

    static func shows(defaults: UserDefaults = .standard, now: Date = .now) -> Bool {
        shows(lastActive: defaults.object(forKey: AppConstants.introLastActiveKey) as? Date, now: now)
    }

    static func markActive(defaults: UserDefaults = .standard, now: Date = .now) {
        defaults.set(now, forKey: AppConstants.introLastActiveKey)
    }
}
