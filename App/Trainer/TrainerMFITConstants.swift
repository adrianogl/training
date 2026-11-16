import Foundation
import Insights

enum TrainerMFITConstants {
    static let source = "vem do MFIT"
    static let lightLeg = "perna leve"
    static let heavyLeg = "perna pesada"
    static let regionNames: [TrainerStrengthGroup: String] = [.upper: "superiores", .lower: "pernas", .fullBody: "corpo todo", .core: "core"]
    static let keptDefaultsKey = "trainerLegSwapKept"
    static let swapButton = "Trocar dias"
    static let keepButton = "Manter"
    static let qualityKinds: Set<String> = ["threshold", "vo2max", "long"]
    static let easyKinds: Set<String> = ["easy", "optionalEasy"]
}
