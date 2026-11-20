import Foundation
import Observation
import UIKit

@MainActor @Observable final class InstallNoticeModel {
    private typealias C = InstallNoticeConstants

    private(set) var card: InstalledCard?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let version: String
    @ObservationIgnored private let expiry: Date?
    @ObservationIgnored private let scheduler: any NotificationScheduling
    @ObservationIgnored private let isActive: @MainActor () -> Bool
    @ObservationIgnored private let settle: @Sendable () async -> Void
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let calendar: Calendar

    init(
        defaults: UserDefaults = .standard, version: String = AppBuildInfo().version, expiry: Date? = ProvisioningProfile.expiration(),
        scheduler: any NotificationScheduling = UserNotificationScheduler(),
        isActive: @escaping @MainActor () -> Bool = { UIApplication.shared.applicationState == .active },
        settle: @escaping @Sendable () async -> Void = { try? await Task.sleep(for: InstallNoticeConstants.settleDelay) },
        now: @escaping () -> Date = { .now }, calendar: Calendar = .current
    ) {
        self.defaults = defaults
        self.version = version
        self.expiry = expiry
        self.scheduler = scheduler
        self.isActive = isActive
        self.settle = settle
        self.now = now
        self.calendar = calendar
        card = defaults.data(forKey: C.cardDefaultsKey).flatMap { try? JSONDecoder().decode(InstalledCard.self, from: $0) }
    }

    var showsCard: Bool {
        card?.day == dayKey(now())
    }

    @discardableResult
    func check() async -> InstallEvent? {
        let event = Self.event(
            lastVersion: defaults.string(forKey: C.versionDefaultsKey), lastExpiry: defaults.object(forKey: C.expiryDefaultsKey) as? Date,
            version: version, expiry: expiry, ranBefore: defaults.object(forKey: AppUpdateConstants.lastCheckDefaultsKey) != nil,
            release: cachedRelease()
        )
        defaults.set(version, forKey: C.versionDefaultsKey)
        if let expiry { defaults.set(expiry, forKey: C.expiryDefaultsKey) }
        guard let event else { return nil }
        if !isActive() { await settle() }
        if !isActive() {
            await scheduler.schedule(
                id: C.notificationId, title: InstallNoticeText.title(event), text: InstallNoticeText.body(event, calendar: calendar),
                link: Self.link(event), at: nil
            )
        } else if case .updated(let version, let notes) = event {
            store(InstalledCard(version: version, notes: notes, day: dayKey(now())))
        }
        return event
    }

    func dismiss() {
        store(nil)
    }

    nonisolated static func event(
        lastVersion: String?, lastExpiry: Date?, version: String, expiry: Date?, ranBefore: Bool, release: AppRelease?
    ) -> InstallEvent? {
        let previous = lastVersion ?? (ranBefore ? "" : nil)
        if let previous, previous.isEmpty || AppVersion.isNewer(version, than: previous) {
            return .updated(version: version, notes: notes(release: release, from: previous, to: version))
        }
        guard let expiry, let lastExpiry, lastVersion == version, expiry > lastExpiry else { return nil }
        return .renewed(expiry: expiry)
    }

    nonisolated static func notes(release: AppRelease?, from previous: String, to version: String) -> [String] {
        guard let release, !AppVersion.isNewer(release.versao_app, than: version),
              previous.isEmpty || AppVersion.isNewer(release.versao_app, than: previous) else { return [] }
        return Array(release.notas.prefix(InstallNoticeConstants.maxNotes))
    }

    nonisolated static func link(_ event: InstallEvent) -> String {
        switch event {
        case .updated: DeepLinkConstants.settings
        case .renewed: DeepLinkConstants.today
        }
    }

    private func cachedRelease() -> AppRelease? {
        defaults.data(forKey: AppUpdateConstants.releaseDefaultsKey).flatMap { try? JSONDecoder().decode(AppRelease.self, from: $0) }
    }

    private func store(_ card: InstalledCard?) {
        self.card = card
        defaults.set(card.flatMap { try? JSONEncoder().encode($0) }, forKey: C.cardDefaultsKey)
    }

    private func dayKey(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
