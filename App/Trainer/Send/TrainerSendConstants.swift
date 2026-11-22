import Foundation
import Insights

enum TrainerSendConstants {
    static let rowSpacing: CGFloat = 12
    static let secondsPerRep = 4
    static let scheduledHour = 6
    static let recordsKey = "trainerSendRecords"
    static let settingsKey = "trainerSendSettings"
    static let windowDays = 7
    static let perSideSuffix = " - cada lado"
    static let skippedKinds: Set<TrainerDayKind> = [.off, .race]
    static let runKeyPrefix = "run|"
    static let strengthKeyPrefix = "strength|"
    static let mfitKeyPrefix = "mfit|"
    static let mfitFallbackCategory = "TOTAL_BODY"
    static let mfitDaysWithoutEnd = 28
}
