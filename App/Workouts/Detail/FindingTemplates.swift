import Foundation
import WorkoutAnalysis

enum FindingTemplates {
    static func text(_ finding: Finding, blocks: [WorkoutBlock]) -> String {
        let facts = finding.facts
        let label = finding.blockOrdinal.flatMap { blocks.indices.contains($0) ? blocks[$0].label : nil } ?? FindingTemplateConstants.genericBlock
        switch finding.kind {
        case .blockInTarget:
            let inTarget = integer(facts[FindingFact.inTarget])
            let total = integer(facts[FindingFact.total])
            return inTarget == total
                ? "Todos os blocos ativos dentro do alvo prescrito: \(inTarget) de \(total)."
                : "\(inTarget) de \(total) blocos ativos dentro do alvo prescrito."
        case .steadyPace:
            return "\(label) com pace constante: \(integer(facts[FindingFact.spread])) s/km de diferença entre as voltas."
        case .lowerHeartRateThanBefore:
            return "\(label) com FC \(integer(facts[FindingFact.delta])) bpm menor que da última vez, no mesmo pace."
        case .goodRecovery:
            return "\(label): a FC caiu \(integer(facts[FindingFact.drop])) bpm desde o pico do bloco anterior."
        case .blockOffTarget:
            return offTarget(finding, label: label, blocks: blocks)
        case .stepIncomplete:
            return incomplete(finding, label: label, blocks: blocks)
        case .paceFade:
            return "\(label) perdeu ritmo no fim: a última volta saiu \(integer(facts[FindingFact.fade])) s/km mais lenta que a mediana."
        case .cardiacDrift:
            let rise = percent(facts[FindingFact.rise])
            return "\(label) com desacoplamento: a FC subiu \(rise) (\(integer(facts[FindingFact.fromHR])) → \(integer(facts[FindingFact.toHR])) bpm) com o pace estável."
        case .zoneAboveTarget:
            return "\(label) em Z\(integer(facts[FindingFact.zone])), acima do esperado para um bloco leve."
        case .hardOnLowReadiness:
            return "Treino forte num dia de prontidão baixa: \(integer(facts[FindingFact.readiness])) de 100."
        case .highAcuteChronic:
            return "Carga aguda:crônica alta: \(decimal(facts[FindingFact.ratio]))."
        }
    }

    private static func offTarget(_ finding: Finding, label: String, blocks: [WorkoutBlock]) -> String {
        let facts = finding.facts
        let status = finding.blockOrdinal.flatMap { blocks.indices.contains($0) ? blocks[$0].status : nil }
        switch status {
        case .aboveTarget, .belowTarget:
            let direction = status == .aboveTarget ? "acima" : "abaixo"
            let heartRate = facts[FindingFact.heartRate].map { "\(integer($0)) bpm" } ?? FindingTemplateConstants.unknown
            guard let low = facts[FindingFact.targetLow], let high = facts[FindingFact.targetHigh] else {
                return "\(label) com FC \(direction) do alvo: \(heartRate)."
            }
            return "\(label) com FC \(direction) do alvo: \(heartRate) para \(integer(low))–\(integer(high)) bpm."
        default:
            let direction = status == .slower ? "mais lento que o prescrito" : status == .faster ? "mais rápido que o prescrito" : "fora do alvo prescrito"
            let pace = WorkoutListModel.paceText(metersPerSecond: facts[FindingFact.speed]) ?? FindingTemplateConstants.unknown
            guard let low = facts[FindingFact.targetLow], let high = facts[FindingFact.targetHigh],
                  let fast = WorkoutListModel.paceClock(metersPerSecond: high),
                  let slow = WorkoutListModel.paceClock(metersPerSecond: low) else {
                return "\(label) \(direction): \(pace)."
            }
            return "\(label) \(direction): \(pace) para \(fast)–\(slow) \(WorkoutConstants.paceUnit)."
        }
    }

    private static func incomplete(_ finding: Finding, label: String, blocks: [WorkoutBlock]) -> String {
        let facts = finding.facts
        let status = finding.blockOrdinal.flatMap { blocks.indices.contains($0) ? blocks[$0].status : nil }
        if let target = facts[FindingFact.targetDistance] {
            let done = distance(facts[FindingFact.distance] ?? 0)
            return status == .notExecuted
                ? "\(label) não executado: 0 m de \(distance(target))."
                : "\(label) não completado: \(done) de \(distance(target))."
        }
        if let target = facts[FindingFact.targetSeconds] {
            let done = WorkoutListModel.clockText(facts[FindingFact.seconds] ?? 0)
            return status == .notExecuted
                ? "\(label) não executado: 0:00 de \(WorkoutListModel.clockText(target))."
                : "\(label) não completado: \(done) de \(WorkoutListModel.clockText(target))."
        }
        return status == .notExecuted ? "\(label) não executado." : "\(label) não completado."
    }

    private static func integer(_ value: Double?) -> Int {
        Int((value ?? 0).rounded())
    }

    private static func decimal(_ value: Double?) -> String {
        (value ?? 0).formatted(.number.precision(.fractionLength(2)).locale(WorkoutConstants.locale))
    }

    private static func percent(_ value: Double?) -> String {
        "\(Int(((value ?? 0) * 100).rounded()))%"
    }

    private static func distance(_ meters: Double) -> String {
        meters < WorkoutConstants.metersPerKilometer
            ? "\(Int(meters.rounded())) m"
            : (meters / WorkoutConstants.metersPerKilometer)
                .formatted(.number.precision(.fractionLength(2)).locale(WorkoutConstants.locale)) + " \(WorkoutConstants.distanceUnit)"
    }
}
