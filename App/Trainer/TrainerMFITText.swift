import Foundation
import Insights
import TrainingCore

enum TrainerMFITText {
    static let note = "Os treinos e os dias vêm do programa do MFIT. Para trocar o dia de um treino, use Ajustes → MFIT. O treinador encaixa as corridas em volta e evita tiro ou longão no dia seguinte à perna pesada."

    static func dayName(_ day: Day) -> String {
        MFITAccountConstants.weekdayNames[day.weekStart.days(until: day)]
    }

    static func shortTitle(_ workout: TrainerWorkout) -> String {
        workout.title.components(separatedBy: " · ").first ?? workout.title
    }

    static func swapHeadline(_ swap: TrainerLegSwap) -> String {
        "\(shortTitle(swap.quality)) de \(dayName(swap.quality.day)) cai no dia seguinte ao \(swap.strengthName) de \(dayName(swap.strengthDay))."
    }

    static func swapBody(_ swap: TrainerLegSwap) -> String {
        "Sugestão: trocar com a rodagem de \(dayName(swap.easy.day)). Assim o treino forte fica longe da perna pesada, e a rodagem passa para \(dayName(swap.quality.day))."
    }

    static func swapReason(_ swap: TrainerLegSwap) -> String {
        "\(shortTitle(swap.quality)) foi para \(dayName(swap.easy.day)) e a rodagem para \(dayName(swap.quality.day)), para não cair no dia seguinte ao \(swap.strengthName) de \(dayName(swap.strengthDay))."
    }
}
