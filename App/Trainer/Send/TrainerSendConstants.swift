import Foundation
import Insights

enum TrainerSendConstants {
    static let recordsKey = "trainerSendRecords"
    static let settingsKey = "trainerSendSettings"
    static let windowDays = 7
    static let namePrefix = "trAIning · "
    static let perSideSuffix = " - cada lado"
    static let skippedKinds: Set<TrainerDayKind> = [.off, .race]
    static let runKeyPrefix = "run|"
    static let strengthKeyPrefix = "strength|"
}
