import Foundation

enum DeviceSyncConstants {
    static let preferenceStateKey = "deviceSync.preferences"
    static let chatStateKey = "deviceSync.chats"
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
    ]
    static let trackedPrefixes = [CoursePointsConstants.defaultsPrefix]
}
