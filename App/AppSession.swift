import BackgroundTasks
import Foundation
import GarminAPI
import Observation
import RemoteSync
import UIKit
import UserNotifications

@MainActor @Observable final class AppSession {
    let account: AccountModel
    private(set) var model: AppModel?

    @ObservationIgnored private let makeScope: @MainActor (AuthUser) -> AccountScope
    @ObservationIgnored private let makeModel: @MainActor (AccountScope, AccountModel) -> AppModel
    @ObservationIgnored private let migration: LegacyDataMigration?
    @ObservationIgnored private let publish: @MainActor (AccountScope?) -> Void
    @ObservationIgnored private let startBackgroundWork: @MainActor (AppModel) -> Void
    @ObservationIgnored private let stopBackgroundWork: @MainActor () -> Void

    init(
        account: AccountModel,
        makeScope: @escaping @MainActor (AuthUser) -> AccountScope,
        makeModel: @escaping @MainActor (AccountScope, AccountModel) -> AppModel,
        migration: LegacyDataMigration?,
        publish: @escaping @MainActor (AccountScope?) -> Void = AccountScope.publish,
        startBackgroundWork: @escaping @MainActor (AppModel) -> Void = AppSession.startLiveBackgroundWork,
        stopBackgroundWork: @escaping @MainActor () -> Void = AppSession.stopLiveBackgroundWork
    ) {
        self.account = account
        self.makeScope = makeScope
        self.makeModel = makeModel
        self.migration = migration
        self.publish = publish
        self.startBackgroundWork = startBackgroundWork
        self.stopBackgroundWork = stopBackgroundWork
        account.legacyKey = { [weak self] in self?.legacyBearer() }
        account.onSignedIn = { [weak self] user in self?.open(user) }
        account.onSignedOut = { [weak self] signOut in await self?.close(erasing: signOut.deleted) }
        if account.isSignedIn, let user = account.user { open(user) }
    }

    func open(_ user: AuthUser) {
        open(scope: makeScope(user))
    }

    func open(scope: AccountScope) {
        guard model?.scope.id != scope.id else { return }
        scope.prepare()
        migration?.run(into: scope)
        publish(scope)
        let model = makeModel(scope, account)
        self.model = model
        startBackgroundWork(model)
    }

    func close(erasing: Bool) async {
        guard let model else { return }
        self.model = nil
        publish(nil)
        stopBackgroundWork()
        await model.stopWork()
        if erasing { model.scope.erase() }
    }

    private func legacyBearer() -> String? {
        migration?.legacyKey(AppConstants.remoteSyncKeychainAccount).flatMap { try? RemoteKeys(syncKey: $0).bearer }
    }

    static func live(environment: [String: String] = ProcessInfo.processInfo.environment) -> AppSession {
        let isTestHost = environment[AppConstants.testHostEnvironmentVariable] != nil
        if !isTestHost { FreshInstall.clearLeftoverKeychain() }
        let transport = URLSessionTransport()
        let baseURL = RemoteSyncModel.baseURL(environment: environment)
        let account = AccountModel(transport: transport, baseURL: baseURL)
        let makeModel: @MainActor (AccountScope, AccountModel) -> AppModel = { scope, account in
            AppModel.live(scope: scope, account: account, transport: transport, remoteBaseURL: baseURL, environment: environment)
        }
        guard !isTestHost else {
            let session = AppSession(
                account: account, makeScope: { _ in .testHost }, makeModel: makeModel, migration: nil,
                startBackgroundWork: { WorkoutFinishNotifier.shared.start(model: $0) }
            )
            session.open(scope: .testHost)
            return session
        }
        return AppSession(account: account, makeScope: { AccountScope.live(email: $0.email) }, makeModel: makeModel, migration: .live)
    }

    static func startLiveBackgroundWork(_ model: AppModel) {
        WorkoutFinishNotifier.shared.start(model: model)
        BackgroundSync.schedule(readinessComplete: false)
        let task = UIApplication.shared.beginBackgroundTask()
        Task {
            await model.refreshInstallState()
            UIApplication.shared.endBackgroundTask(task)
        }
    }

    static func stopLiveBackgroundWork() {
        WorkoutFinishNotifier.shared.detach()
        BGTaskScheduler.shared.cancelAllTaskRequests()
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
}
