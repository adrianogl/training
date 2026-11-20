import CoreGraphics
import Insights
import SwiftUI
import TrainingCore

enum StrengthConstants {
    static let detailRowSpacing: CGFloat = 10
    static let openSymbol = "chevron.right"
    static let typeKey = "strength_training"
    static let programFileName = "strength-mfit.json"
    static let weekdaysDefaultsKey = "strengthWeekdays"
    static let defaultWeekdays = [0, 2, 4]
    static let noWeekday = -1
    static let historyWeeks = 12
    static let volumeWeeks = 6
    static let viewWidth: CGFloat = 724
    static let viewHeight: CGFloat = 1448
    static let backOffset: CGFloat = 724
    static let detailMapHeight: CGFloat = 220
    static let freqHeight: CGFloat = 44
    static let sparkHeight: CGFloat = 26
    static let heat: [Color] = [Color(hex: 0xF2C94C), Color(hex: 0xF2994A), Color(hex: 0xEB5757)]
    static let muscleOff = Color(light: 0xC9CED6, dark: 0x3A4350)
    static let bodySkin = Color(light: 0xE3E6EA, dark: 0x262E38)
    static let skinSlugs: Set<String> = ["head", "hair", "neck", "hands", "feet", "ankles", "knees"]
    static let slugGroups: [String: MuscleGroup] = [
        "chest": .chest, "obliques": .obliques, "abs": .abs, "biceps": .biceps, "triceps": .triceps, "forearm": .forearms,
        "deltoids": .shoulders, "trapezius": .traps, "upper-back": .lats, "lower-back": .lowerBack, "gluteal": .glutes,
        "quadriceps": .quads, "hamstring": .hamstrings, "adductors": .adductors, "calves": .calves, "tibialis": .calves,
    ]
    static let volumeGroups: [MuscleGroup] = [.glutes, .quads, .hamstrings, .calves, .chest, .lats, .shoulders, .abs]
    static let secondsPerMinute = 60.0
    static let groupTotalsLimit = 8
    static let evolutionGroupsLimit = 5
    static let reportGroupsLimit = 3
    static let loadsCardLimit = 3
    static let watchLoadsWeeks = 8
    static let watchLoadsPerLoad = 8
    static let recordNoticeDays = 2
    static let recordLink = "training://evolucao"
    static let recordNotifiedKey = "strengthRecordsNotified"
    static let recordGold = Color(hex: 0xF2C94C)
    static let sparkWidth: CGFloat = 84
    static let sparkLineHeight: CGFloat = 26
    static let loadChartHeight: CGFloat = 200
    static let workoutColors: [Color] = [Color(light: 0x7B5CD6, dark: 0xB59CFF), Color(light: 0x1E9E90, dark: 0x5FD3C6), Color(light: 0xC27A12, dark: 0xF2B04A), Color(light: 0x4E6A00, dark: 0xC8F05A)]
    static let syntheticIdFactor: Int64 = 100_000
    static let syntheticEpoch = Day(year: 2000, month: 1, day: 1)
}
