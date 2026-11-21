import Foundation
import Insights

enum StrengthPlanUIConstants {
    static let weeksRange = 1...24
    static let defaultWeeks = 8
    static let objectiveOrder: [StrengthObjective] = [.mobility, .strength, .prevention]
    static let validityOrder: [StrengthPlanValidityMode] = [.untilRace, .weeks, .untilDate]
    static let builderOrder: [StrengthPlanBuilder] = [.trainer, .claude]
    static let weekdayPlural = ["segundas", "terças", "quartas", "quintas", "sextas", "sábados", "domingos"]
    static let migrationDismissedKey = "strengthPlanMigrationDismissed"
    static let innerRadius = DSRadius.medium
    static let segmentRadius: CGFloat = 9
    static let segmentPadding: CGFloat = 3
    static let segmentHeight: CGFloat = 32
    static let hitSize: CGFloat = 44
    static let rowMinHeight: CGFloat = 44
    static let dayColumnWidth: CGFloat = 44
    static let meterHeight: CGFloat = 6
    static let meterOpacity = 0.75
    static let stepperSymbolMinus = "minus"
    static let stepperSymbolPlus = "plus"
    static let spacing: CGFloat = 10
    static let fieldPadding: CGFloat = 12
}
