import Foundation
import Insights
import Metrics
import SwiftUI

enum TrainerConstants {
    static let tagSpacing: CGFloat = 6
    static let detailSpacing: CGFloat = 10
    static let actionIconSize: CGFloat = 30
    static let strengthDone = "feita"
    static let strengthTitle = "Força"
    static let nestedStepInset: CGFloat = 18
    static let storeFileName = "trainer-plan.json"
    static let seenVersionDefaultsKey = "trainerSeenVersion"
    static let strengthMigratedDefaultsKey = "trainerStrengthMigrated"
    static let syncUpdatedAtDefaultsKey = "trainerSyncUpdatedAt"
    static let syncDeletedDefaultsKey = "trainerSyncDeleted"
    static let syncNeedsPushDefaultsKey = "trainerSyncNeedsPush"
    static let readinessKeptDefaultsKey = "trainerReadinessKeptDay"
    static let cycleSummariesDefaultsKey = "trainerCycleSummaries"
    static let seenCycleEndDefaultsKey = "trainerSeenCycleEnd"
    static let keptDaysCycleEndDefaultsKey = "trainerKeptDaysCycleEnd"
    static let intervalPairCount = 2
    static let scoreboardWeeks = 12
    static let readinessEasyKilometers = 8
    static let externalWeeksAhead = 2
    static let historyDays = 120
    static let deepAnalysisDays = 28
    static let highlightSeconds = 1.2
    static let expandedFutureWeeks = 1
    static let predictionDistances: [Double] = [5_000, 10_000, 21_097.5, 42_195]
    static let defaultDeadlineSeconds: TimeInterval = 90 * 86_400
    static let defaultRequestSeconds: TimeInterval = 3 * 86_400
    static let stripCellWidth: CGFloat = 64
    static let stripSpacing: CGFloat = 4
    static let dayBarWidth: CGFloat = 6
    static let dayDateWidth: CGFloat = 40
    static let dayRowCorner = DSRadius.card
    static let weekGroupPadding: CGFloat = 6
    static let weekGroupCorner = DSRadius.card + weekGroupPadding
    static let shapeHeight: CGFloat = 44
    static let shapeSpacing: CGFloat = 2
    static let turnMarkWidth: CGFloat = 2
    static let turnRowPadding: CGFloat = 10
    static let turnRowRadius: CGFloat = 12
    static let shapeMinimumWidth: CGFloat = 3
    static let shapeRestWidth: CGFloat = 6
    static let changeSymbolSize: CGFloat = 24
    static let goalIconSize: CGFloat = 38
    static let weekdayCount = 7
    static let metersPerKilometer = 1_000.0
    static let weeklyKilometersRange = 10...150
    static let lightWeekChoices = 12
    static let goalPaceRange = 150...480
    static let goalPaceStep = 5
    static let defaultLongPace = 360.0
    static let goalPaceDefault = 240
    static let goalDistanceRange = 3...100
    static let goalDistanceDefault = 21
    static let peakKilometersCeiling = 200
    static let previewLineLimit = 6
    static let swapColumns = 4
    static let paceKinds: [TrainerPaceKind] = [.easy, .long, .threshold, .vo2max, .race]
    static let editableKinds: [TrainerDayKind] = [.easy, .threshold, .vo2max, .optionalEasy, .long, .off]
    static let weekdayShort = ["seg", "ter", "qua", "qui", "sex", "sáb", "dom"]
    static let weekdayFull = ["segunda", "terça", "quarta", "quinta", "sexta", "sábado", "domingo"]
    static let monthShort = ["jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"]
    static let monthFull = [
        "janeiro", "fevereiro", "março", "abril", "maio", "junho",
        "julho", "agosto", "setembro", "outubro", "novembro", "dezembro",
    ]
    static let longModes: [TrainerLongMode] = [.continuous, .blocks]
    static let strengthGroups: [TrainerStrengthGroup] = [.upper, .lower, .fullBody, .core, .mobility]
    static let adjustmentsAnchor = "trainerAdjustmentsAnchor"
    static let locale = Locale(identifier: "pt_BR")

    static let shortcuts: [TrainerRequestShortcut] = [
        TrainerRequestShortcut(category: .travel, title: "Viagem", prefix: "Viagem, sem lugar bom para correr. "),
        TrainerRequestShortcut(category: .pain, title: "Dor ou incômodo", prefix: "Dor ou incômodo em "),
        TrainerRequestShortcut(category: .fatigue, title: "Cansaço", prefix: "Cansaço acumulado nos últimos dias. "),
        TrainerRequestShortcut(category: .moreTime, title: "Mais tempo livre", prefix: "Tenho mais tempo livre para treinar. "),
        TrainerRequestShortcut(category: .goalChanged, title: "Mudou a meta", prefix: "A meta mudou: "),
    ]

    static func color(for kind: TrainerDayKind) -> Color {
        switch kind {
        case .easy, .optionalEasy: BrandColors.fitness
        case .threshold: BrandColors.attention
        case .vo2max: BrandColors.rest
        case .long: BrandColors.race
        case .off: BrandColors.track
        case .race: BrandColors.accentFill
        }
    }

    static let readinessFactorNames: [ReadinessComponent: String] = [
        .hrv: "HRV", .sleep: "sono", .bodyBattery: "Body Battery", .load: "carga",
    ]

    static func defaultLoad(for group: TrainerStrengthGroup) -> TrainerStrengthLoad {
        group == .lower ? .heavy : .light
    }

    static func color(for phase: TrainerPhase) -> Color {
        switch phase {
        case .general: BrandColors.dim
        case .base: BrandColors.fitness
        case .build: BrandColors.attention
        case .specific: BrandColors.race
        case .taper: BrandColors.zones[1]
        }
    }

    static func color(for step: TrainerStepKind) -> Color {
        switch step {
        case .warmup: BrandColors.zones[1]
        case .work: BrandColors.attention
        case .recovery, .cooldown: BrandColors.fitness
        case .steady: BrandColors.accentFill
        }
    }

    static func shapeHeight(for step: TrainerStepKind) -> Double {
        switch step {
        case .work: 0.85
        case .steady: 0.6
        case .warmup: 0.4
        case .recovery, .cooldown: 0.25
        }
    }

    static func color(for tone: TrainerTone) -> Color {
        switch tone {
        case .good: BrandColors.accent
        case .attention: BrandColors.attention
        case .bad: BrandColors.danger
        case .dim: BrandColors.dim
        }
    }

    static func color(for tone: TrainerChangeTone) -> Color {
        switch tone {
        case .race: BrandColors.race
        case .attention: BrandColors.attention
        case .good: BrandColors.accent
        case .info: BrandColors.fitness
        case .rest: BrandColors.rest
        }
    }

    static func style(for kind: TrainerChangeKind) -> TrainerChangeStyle {
        switch kind {
        case .changed: TrainerChangeStyle(symbol: "≈", tone: .attention)
        case .added: TrainerChangeStyle(symbol: "+", tone: .info)
        case .removed: TrainerChangeStyle(symbol: "↓", tone: .rest)
        case .moved: TrainerChangeStyle(symbol: "↔", tone: .attention)
        case .unchanged: TrainerChangeStyle(symbol: "=", tone: .good)
        case .skeleton: TrainerChangeStyle(symbol: "↔", tone: .race)
        case .newWeek: TrainerChangeStyle(symbol: "+", tone: .info)
        }
    }
}
