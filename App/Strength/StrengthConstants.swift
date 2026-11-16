import CoreGraphics
import Insights
import SwiftUI
import TrainingCore

enum StrengthConstants {
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
    static let todayMapHeight: CGFloat = 150
    static let weekMapHeight: CGFloat = 150
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
    static let syntheticIdFactor: Int64 = 100_000
    static let syntheticEpoch = Day(year: 2000, month: 1, day: 1)
}
