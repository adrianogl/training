import Foundation

enum AccountScopeConstants {
    static let accountsFolderName = "Accounts"
    static let suitePrefix = "dev.aglv.training.account."
    static let testHostId = "test-host"
    static let signedOutId = "signed-out"
    static let idByteCount = 16
    static let keychainSeparator = "."
    static let migratedOwnerDefaultsKey = "accountScope.legacyOwner"

    static let keychainAccounts = [
        AppConstants.keychainAccount,
        AppConstants.remoteSyncKeychainAccount,
        AppConstants.watchTokenKeychainAccount,
        AppConstants.garminSessionKeychainAccount,
    ]

    static var legacySupportItems: [String] {
        let store = AppConstants.storeFileName
        let base = (store as NSString).deletingPathExtension
        return [
            store, store + "-shm", store + "-wal", "." + base + "_SUPPORT",
            TrainerConstants.storeFileName,
            WorkoutChatConstants.folderName,
            WorkoutChatConstants.raceFolderName,
            WorkoutChatConstants.evolutionFolderName,
            WorkoutChatConstants.plannedFolderName,
            TrainerChatConstants.folderName,
        ]
    }

    static let legacyCacheItems = [ScreenSnapshotConstants.directoryName]

    static let scopedDefaultsKeys: Set<String> = [
        AppConstants.weeklyGoalDefaultsKey,
        AppConstants.plannedWeeksDefaultsKey,
        AppConstants.garminReadinessDefaultsKey,
        AppConstants.watchReadinessDefaultsKey,
        BackgroundConstants.noticeEnabledDefaultsKey,
        BackgroundConstants.noticeMinimumMinutesDefaultsKey,
        BackgroundConstants.notifiedDayDefaultsKey,
        BackgroundConstants.readyDayDefaultsKey,
        BackgroundConstants.readyAtDefaultsKey,
        BackgroundConstants.lastAppOpenDefaultsKey,
        WorkoutNoticeConstants.enabledKey,
        WorkoutNoticeConstants.enabledAtKey,
        WorkoutNoticeConstants.notifiedKey,
        WorkoutNoticeConstants.notifiedWorkoutsKey,
        WorkoutNoticeConstants.pendingKey,
        StravaConstants.ledgerDefaultsKey,
        TrainerConstants.seenVersionDefaultsKey,
        TrainerConstants.strengthMigratedDefaultsKey,
        TrainerConstants.syncUpdatedAtDefaultsKey,
        TrainerConstants.syncDeletedDefaultsKey,
        TrainerConstants.syncNeedsPushDefaultsKey,
        TrainerConstants.readinessKeptDefaultsKey,
        ShareStudioConstants.formatDefaultsKey,
        ShareStudioConstants.aspectDefaultsKey,
        ShareStudioConstants.coloringDefaultsKey,
        ShareStudioConstants.hidesEndsDefaultsKey,
        ShareConstants.templateDefaultsKey,
        ShareConstants.fieldsDefaultsKey,
    ]

    static let scopedDefaultsPrefixes = [
        GeneratedTextConstants.keyPrefix,
        CoursePointsConstants.defaultsPrefix,
        "remoteSync.",
    ]
}
