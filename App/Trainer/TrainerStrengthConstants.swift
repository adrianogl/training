import Foundation
import Insights

enum TrainerStrengthConstants {
    static let prefsKey = "trainerStrengthPrefs"
    static let standaloneKey = "trainerStrengthStandalone"
    static let completedSets = 3
    static let painReviewDays = 7
    static let minuteOptions = [15, 25, 30, 45, 60]
    static let focusOrder: [TrainerStrengthGroup] = [.upper, .lower, .fullBody, .core]
    static let sourceOrder: [TrainerStrengthSource] = [.mfit, .trainer]
    static let intensityOrder: [TrainerStrengthIntensity] = [.light, .moderate, .heavy]
    static let placeOrder: [StrengthPlace] = [.gym, .home, .bodyweight]
    static let regionOrder: [BodyRegion] = [.knee, .calfAchilles, .lowerBack, .hip, .shoulder]
    static let swapSymbol = "arrow.triangle.2.circlepath"
    static let swapTargetWidth: CGFloat = 28
    static let painSymbol = "bandage"
    static let suggestionSymbol = "sparkles"
    static let rowSpacing: CGFloat = 10
    static let workoutTitle = "Força"
    static let exercisesTitle = "Exercícios"
    static let bannerCorner: CGFloat = 14
    static let bannerBorder: CGFloat = 1.5
    static let bannerTint = 0.10
    static let dayChipCorner: CGFloat = 10
}
