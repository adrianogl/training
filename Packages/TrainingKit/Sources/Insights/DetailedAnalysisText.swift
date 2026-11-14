import Foundation
import WorkoutAnalysis

enum DetailedAnalysisText {
    static let completionTitleFull = "Completou a distância planejada"
    static let completionTitleShort = "Fez %d%% da distância planejada"
    static let completionText = "Foram %@ de %@ km planejados (%d%%)."
    static let completionAverage = " Nos %d treinos parecidos, a média foi %d%%."

    static let fadeTitle = "O pace caiu a partir do km %d"
    static let fadeText = "A partir do km %d o pace ficou %d s/km mais lento que a mediana dos km 1 a %d (%@/km)."
    static let fadeSimilar = " Nos treinos parecidos, a queda costuma vir no km %d."

    static let driftTitle = "Deriva da FC de %d%%"
    static let driftText = "A velocidade por batimento da segunda metade foi %d%% pior que a da primeira."
    static let driftNoneTitle = "FC estável no mesmo pace"
    static let driftNoneText = "A velocidade por batimento da segunda metade ficou igual à da primeira."
    static let driftAverage = " Nos treinos parecidos, a média foi %d%%."
    static let driftNormal = " Até %d%% é o normal num treino longo."

    static let startFastTitle = "Começo rápido pesa na segunda metade"
    static let startTitle = "Pace dos primeiros %d km"
    static let startText = "Os %d primeiros km saíram a %@/km."
    static let startGroups = " Com início mais rápido que %@/km, %d de %d treinos caíram antes do km %d; com início mais lento, %d de %d."

    static let readinessLowTitle = "Prontidão baixa encurta o treino"
    static let readinessTitle = "Prontidão e distância feita"
    static let readinessText = "Nos %d treinos com prontidão abaixo de %d, você completou em média %d%% da distância; com %d ou mais, %d%%."
    static let readinessToday = " Hoje a prontidão era %d."

    static let weekTitleHeavy = "Semana pesada antes do treino"
    static let weekTitle = "Carga dos 7 dias anteriores"
    static let weekText = "Nos %d dias anteriores você correu %@ km, %d%% %@ da média semanal das %d semanas antes (%@ km)."
    static let weekAbove = "acima"
    static let weekBelow = "abaixo"
    static let weekIntervals = " Houve tiros nesses dias."

    static let hrAtPaceImprovedTitle = "A FC no mesmo pace está caindo"
    static let hrAtPaceWorseTitle = "A FC no mesmo pace está subindo"
    static let hrAtPaceStableTitle = "A FC no mesmo pace está estável"
    static let hrAtPaceText = "No pace de %@/km, a FC média dos treinos parecidos foi de %d para %d bpm em %d dias."

    static let pausesNoneTitle = "Treino contínuo, sem pausas"
    static let pausesNoneText = "O treino foi contínuo por %@ km."
    static let pausesTitle = "Pausas durante o treino"
    static let pausesText = "Foram %d pausas, a primeira no km %@. O maior trecho contínuo teve %@ km."
    static let pausesOneText = "Foi 1 pausa, no km %@. O maior trecho contínuo teve %@ km."

    static let repsTitle = "Consistência dos tiros"
    static let repsText = "Os %d tiros variaram %d s/km de pace entre si (desvio padrão)."
    static let repsRecovery = " Na recuperação, a FC caiu %d bpm em média."

    static let goalTitle = "Meta: %@"
    static let goalText = "%@. %@"

    static let startRecommendation = "Primeiros %d km a %@/km"
    static let startReason = "Nos treinos parecidos sem queda antes do km %d, os %d primeiros km saíram a %@/km (mediana); hoje foram a %@/km."
    static let fuelRecommendation = "Gel no km %d"
    static let fuelReason = "O pace de hoje caiu a partir do km %d."
    static let fuelSimilar = " Nos treinos parecidos, a queda costuma vir no km %d."
    static let readinessRecommendation = "Treino forte em dia de prontidão %d ou mais"
    static let readinessReason = "Com prontidão abaixo de %d você completou em média %d%% da distância, contra %d%%."
    static let weekRecommendation = "Aliviar a semana antes do treino"
    static let weekReason = "Os 7 dias anteriores somaram %@ km, %d%% acima da média semanal."
}

enum DetailedFormat {
    static func pace(_ seconds: Double) -> String {
        WorkoutFormat.clock(seconds)
    }

    static func kilometers(_ value: Double) -> String {
        decimal(value, digits: 1)
    }

    static func decimal(_ value: Double, digits: Int) -> String {
        value.formatted(.number.precision(.fractionLength(digits)).locale(WorkoutFormat.locale))
    }

    static func whole(_ value: Double) -> Int {
        Int(value.rounded())
    }
}
