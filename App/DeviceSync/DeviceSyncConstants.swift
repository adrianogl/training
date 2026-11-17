import Foundation

enum DeviceSyncConstants {
    static let preferenceStateKey = "deviceSync.preferences"
    static let chatStateKey = "deviceSync.chats"
    static let strengthStateKey = "deviceSync.strength"
    static let strengthId = "strengthProgram"
    static let chatIndexName = WorkoutChatConstants.indexName
    static let chatFileExtension = "json"
    static let plistValueKey = "v"
    static let workoutTag = "workout"
    static let raceTag = "race"
    static let evolutionTag = "evolution"
    static let plannedTag = "planned"
    static let trainerTag = "trainer"
    static let trackedKeys = [
        AppConstants.weeklyGoalDefaultsKey,
        StrengthConstants.weekdaysDefaultsKey,
        TrainerConstants.cycleSummariesDefaultsKey,
        TrainerConstants.readinessKeptDefaultsKey,
        TrainerMFITConstants.keptDefaultsKey,
        StravaConstants.ledgerDefaultsKey,
        TrainerConstants.seenVersionDefaultsKey,
        TrainerConstants.seenCycleEndDefaultsKey,
        BackgroundConstants.notifiedDayDefaultsKey,
        WorkoutNoticeConstants.notifiedKey,
        WorkoutNoticeConstants.notifiedWorkoutsKey,
        StrengthConstants.recordNotifiedKey,
        TrainerSignalNotifierConstants.notifiedDefaultsKey,
        RacePlanConstants.choiceDefaultsKey,
        BackgroundConstants.noticeEnabledDefaultsKey,
        BackgroundConstants.noticeMinimumMinutesDefaultsKey,
        WorkoutNoticeConstants.enabledKey,
        ShareStudioConstants.formatDefaultsKey,
        ShareStudioConstants.aspectDefaultsKey,
        ShareStudioConstants.coloringDefaultsKey,
        ShareStudioConstants.hidesEndsDefaultsKey,
        ShareConstants.templateDefaultsKey,
        ShareConstants.fieldsDefaultsKey,
        GarminZonesConstants.enabledDefaultsKey,
    ]
    static let unionKeys: Set<String> = [
        WorkoutNoticeConstants.notifiedKey,
        WorkoutNoticeConstants.notifiedWorkoutsKey,
        StrengthConstants.recordNotifiedKey,
        TrainerSignalNotifierConstants.notifiedDefaultsKey,
    ]
    static let watchTokenId = "watchToken"
    static let mfitTokenId = "mfitToken"
    static let garminKeyId = "garminApiKey"
    static let credentialStatePrefix = "deviceSync.credential."
    static let trackedPrefixes = [CoursePointsConstants.defaultsPrefix]
}
