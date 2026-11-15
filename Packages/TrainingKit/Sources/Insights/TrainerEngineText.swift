import Foundation
import TrainingCore

enum TrainerEngineText {
    static let weekdayNames = ["segunda", "terça", "quarta", "quinta", "sexta", "sábado", "domingo"]
    static let weekdayShort = ["seg", "ter", "qua", "qui", "sex", "sáb", "dom"]
    static let offTitle = "Folga"
    static let optionalNote = "só se a prontidão ≥ 60"
    static let painWarning = "Dor que persiste é caso para médico ou fisioterapeuta."
    static let travelRationale = "Viagem no período: o treino sai da janela e vem para antes."
    static let travelLongTitle = "Rodagem 6 km"
    static let skeletonFallback = "O esqueleto da semana mudou depois do ajuste."
    static let paceReason = "Os paces foram recalculados com as corridas dos últimos 90 dias."

    static func kilometers(_ meters: Double) -> String {
        let km = meters / 1_000
        if abs(km - km.rounded()) < 0.05 { return "\(Int(km.rounded())) km" }
        return String(format: "%.1f", km).replacingOccurrences(of: ".", with: ",") + " km"
    }

    static func restClock(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static func restSummary(_ seconds: Double) -> String { "parado \(restClock(seconds))" }

    static func restRule(kind: TrainerDayKind, seconds: Double) -> String {
        let reason = kind == .threshold ? "1 min para cada 5 min de bloco" : "um pouco menos que o tempo do tiro"
        return "Descanso de \(restClock(seconds)) parado, \(reason)."
    }

    static func distance(_ meters: Double) -> String {
        meters >= 2_000 ? kilometers(meters) : "\(Int(meters.rounded())) m"
    }

    static func pace(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static func paceRange(_ low: Double, _ high: Double) -> String {
        "\(pace(low))–\(pace(high))/km"
    }

    static func clock(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        if total >= 3_600 { return String(format: "%d:%02d:%02d", total / 3_600, (total % 3_600) / 60, total % 60) }
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static func date(_ day: Day) -> String {
        String(format: "%02d/%02d", day.day, day.month)
    }

    static func weekday(_ day: Day) -> String {
        weekdayShort[day.weekStart.days(until: day)]
    }

    static func weekdayName(_ day: Day) -> String {
        weekdayNames[day.weekStart.days(until: day)]
    }

    static func dayLabel(_ day: Day) -> String {
        "\(weekday(day)) \(date(day))"
    }

    static func stageLabel(_ stage: TrainerQualityStage) -> String {
        "\(stage.repeats) × \(distance(stage.meters))"
    }

    static func title(kind: TrainerDayKind, meters: Double, stage: TrainerQualityStage? = nil) -> String {
        switch kind {
        case .threshold: "Limiar \(stage.map(stageLabel) ?? kilometers(meters))"
        case .vo2max: "VO2 máx \(stage.map(stageLabel) ?? kilometers(meters))"
        case .long: "Longão \(kilometers(meters))"
        case .optionalEasy: "Rodagem opcional \(kilometers(meters))"
        case .race: "Prova \(kilometers(meters))"
        case .off: offTitle
        case .easy: "Rodagem \(kilometers(meters))"
        }
    }

    static func kindName(_ kind: TrainerDayKind) -> String {
        switch kind {
        case .threshold: "Limiar"
        case .vo2max: "VO2 máx"
        case .long: "Longão"
        case .optionalEasy, .easy: "Rodagem"
        case .race: "Prova"
        case .off: "Folga"
        }
    }

    static func skeletonSummary(_ week: TrainerWeek) -> String {
        "\(kilometers(week.plannedMeters)), longão \(kilometers(week.longMeters))"
    }

    static func createdSummary(weeks: Int, target: String, phases: String) -> String {
        "Plano de \(weeks) semanas para \(target): \(phases). O detalhe treino a treino cobre os próximos 15 dias."
    }

    static func createdSkeleton(weeks: Int) -> String {
        "Esqueleto de \(weeks) semanas calculado com o volume das últimas 4 semanas e o maior longão dos últimos 30 dias."
    }

    static let skeletonLabel = "Esqueleto"

    static func weeksLabel(_ count: Int) -> String { "\(count) semanas" }

    static func newWeek(_ index: Int) -> String { "Semana \(index) detalhada" }

    static func newWeekReason(count: Int, meters: Double) -> String {
        "A janela de 15 dias chegou a essa semana: \(count) treinos, \(kilometers(meters)) planejados."
    }

    static func skeletonTitle(first: Int, last: Int) -> String {
        first == last ? "Semana \(first)" : "Semanas \(first) a \(last)"
    }

    static func skeletonLater(_ reason: String) -> String {
        "\(reason) As semanas seguintes avançam a partir daqui."
    }

    static let unchangedTitle = "Plano mantido"

    static func longFailure(_ findings: TrainerFindings, day: Day, next: Double?) -> String {
        var text: String
        if findings.longFailed {
            text = "O longão de \(date(day)) parou em \(kilometers(findings.longDone ?? 0)) dos \(kilometers(findings.longPlanned ?? 0))."
        } else {
            text = "O longão de \(date(day)) teve pausas."
        }
        let nextText = next.map { "O próximo longão fica em \(kilometers($0))" } ?? "O próximo longão repete a distância"
        text += " \(nextText)\(findings.longReduced ? ", 2 km abaixo do planejado" : ""), e o esqueleto atrasa uma semana."
        return text
    }

    static func workoutChecked(_ day: Day) -> String {
        "O treino de \(date(day)) foi registrado. O plano segue o esqueleto."
    }

    static func qualityMiss(_ miss: TrainerQualityMiss, legs: String? = nil) -> String {
        let eve = legs.map { " Na véspera teve \($0), força de pernas." } ?? ""
        return "O \(kindName(miss.kind).lowercased()) de \(date(miss.day)) ficou fora do alvo em \(miss.total - miss.onTarget) de \(miss.total) trechos.\(eve) O próximo desce uma etapa e a recuperação sobe 200 m."
    }

    static func lowReadiness(_ value: Double, weekly: Bool) -> String {
        let label = weekly ? "A prontidão média da semana foi \(Int(value.rounded()))" : "A prontidão no dia do treino foi \(Int(value.rounded()))"
        return "\(label). O volume da próxima semana cai 10%."
    }

    static func weekClosed(_ index: Int) -> String {
        "A semana \(index) fechou dentro do planejado. O plano segue o esqueleto."
    }

    static let fatigueSummary = "Cansaço relatado. O volume da próxima semana cai 10%."

    static func requestSummary(_ request: TrainerRequest, until: Day) -> String {
        let period = "de \(date(request.from)) a \(date(until))"
        switch request.category {
        case .travel:
            return "Viagem \(period): a qualidade vem para antes do período e o longão vira rodagem de 6 km, voltando no dia seguinte."
        case .pain:
            return "Treinos \(period) viram rodagem leve e o volume cai 30%. \(painWarning)"
        case .moreTime:
            return "Com mais tempo \(period), a rodagem opcional passa a ser obrigatória."
        case .fatigue:
            return fatigueSummary
        case .goalChanged, .other:
            return "Plano recriado a partir de hoje com o histórico atual. Os treinos passados ficam como estão."
        }
    }

    static func travelMoved(_ title: String, from: Day, to: Day, until: Day) -> String {
        "Você viaja de \(date(from)) a \(date(until)). \(title) vem para \(weekday(to)) \(date(to)), antes do período."
    }

    static func travelDropped(from: Day, until: Day) -> String {
        "Você viaja de \(date(from)) a \(date(until)): o treino do período vira rodagem leve."
    }

    static func travelVacated(from: Day, until: Day) -> String {
        "Você viaja de \(date(from)) a \(date(until)): o treino de qualidade sai do período e o dia vira folga."
    }

    static func travelLongReturn(from: Day, until: Day, to: Day) -> String {
        "O longão do período de viagem (\(date(from)) a \(date(until))) volta em \(weekday(to)) \(date(to)), no dia seguinte."
    }

    static func painReason(from: Day, until: Day) -> String {
        "Dor relatada de \(date(from)) a \(date(until)): qualidade vira rodagem e o volume cai 30%. \(painWarning)"
    }

    static func moreTimeReason(from: Day, until: Day) -> String {
        "Mais tempo de \(date(from)) a \(date(until)): a rodagem opcional vira obrigatória."
    }

    static func thresholdBasis(_ paces: TrainerPaces, predicted: Double?) -> String {
        let history = "Pace pela mediana de \(paces.thresholdRuns) limiares dos últimos 90 dias."
        switch paces.thresholdSource {
        case .work:
            return "Pace de \(pace(paces.threshold))/km, a mediana dos blocos dos seus últimos \(paces.thresholdWorkRuns ?? 0) limiares."
        case .fallback:
            return "Pace 60 s/km abaixo da rodagem, sem limiares recentes."
        case .prediction, .history, nil:
            return predicted.map { "Pace do 10 km previsto em \(clock($0)) mais 8 s/km." } ?? history
        }
    }

    static func vo2Basis(_ paces: TrainerPaces, predicted: Double?) -> String {
        switch paces.vo2Source {
        case .work:
            return "Pace de \(pace(paces.vo2max))/km, a mediana dos blocos dos seus últimos \(paces.vo2WorkRuns ?? 0) treinos de VO2."
        case .prediction, .history, .fallback, nil:
            return predicted.map { "Pace do 5 km previsto em \(clock($0))." } ?? "Pace 15 s/km abaixo do limiar, sem previsão de 5 km."
        }
    }

    static func qualityRationale(
        kind: TrainerDayKind, title: String, week: TrainerWeek, previous: TrainerWorkout?, previousStatus: TrainerDayStatus?,
        miss: TrainerQualityMiss?, basis: String, restSeconds: Double, legs: String? = nil
    ) -> String {
        let name = kindName(kind)
        let warmup = legs.map { " \(legsWarmup($0))" } ?? ""
        if let miss {
            return "\(name) uma etapa abaixo. Descanso de \(restClock(restSeconds)) parado, 1 min a mais porque o último ficou fora do alvo em \(miss.total - miss.onTarget) de \(miss.total) trechos. \(basis)\(warmup)"
        }
        let rule = restRule(kind: kind, seconds: restSeconds)
        if let previous, previousStatus == .done {
            if previous.title == title {
                return "\(name) com os mesmos \(title.dropFirst(name.count + 1)) do último treino, porque ele saiu no alvo e a progressão sobe a cada duas semanas. \(rule) \(basis)\(warmup)"
            }
            return "\(name) sobe para \(title.dropFirst(name.count + 1)), porque o último treino saiu no alvo. \(rule) \(basis)\(warmup)"
        }
        let phase = phaseName(week.phase)
        let recovery = week.isRecovery ? " Semana de recuperação, uma etapa abaixo." : ""
        return "\(title) na semana \(week.index) (\(phase)).\(recovery) \(rule) \(basis)\(warmup)"
    }

    static func legsNote(_ name: String) -> String { "pernas de ontem (\(name))" }

    static func legsWarmup(_ name: String) -> String {
        "Ontem teve \(name), com as pernas cansadas. O aquecimento continua em \(kilometers(TrainerEngineConstants.warmupMeters))."
    }

    static let noNote = "sem observação"
    static let slowStartNote = "começa mais lento: força ontem"

    static func slowStartRationale(_ name: String) -> String {
        "Os \(kilometers(TrainerEngineConstants.slowStartMeters)) primeiros saem \(Int(TrainerEngineConstants.slowStartSeconds)) s/km acima do pace do longão, porque ontem teve \(name)."
    }

    static func strengthGroupName(_ group: TrainerStrengthGroup) -> String {
        switch group {
        case .upper: "Superiores"
        case .lower: "MMII"
        case .fullBody: "Full body"
        case .core: "Core"
        }
    }

    static let strengthSummary = "Treinos de força atualizados. A corrida se ajusta em volta deles, e a musculação fica como você definiu."
    static let strengthLifted = "Sem força de pernas na véspera, o treino volta ao padrão."

    static func strengthSuggestion(name: String, kind: TrainerDayKind) -> String {
        "Pense em fazer o \(name) no dia do \(kindName(kind).lowercased()), depois da corrida. O plano não muda a musculação sozinho."
    }

    static func longRationale(week: TrainerWeek, previousLong: Double?, cap: Double, note: String?, slowStart: String? = nil) -> String {
        var text: String
        if week.phase == .taper {
            text = "Longão reduzido no polimento, para chegar descansado à prova."
        } else if week.isRecovery {
            text = "Semana de recuperação: 75% do longão anterior."
        } else if let previousLong, week.longMeters > previousLong {
            text = "Longão \(kilometers(week.longMeters - previousLong)) acima do anterior, dentro do teto de \(kilometers(cap)) para essa prova."
        } else {
            text = "Longão de \(kilometers(week.longMeters)) repetido, até o histórico mostrar que fecha sem queda."
        }
        if let note { text += " \(note.prefix(1).uppercased() + note.dropFirst())." }
        if let slowStart { text += " \(slowStartRationale(slowStart))" }
        return text
    }

    static func easyRationale(_ share: TrainerEasyShare) -> String {
        let weeks = TrainerEngineConstants.easyWindowDays / TrainerEngineConstants.daysPerWeek
        let text = "Rodagem de \(kilometers(share.meters))."
        guard share.fromHistory else { return text }
        return "\(text) Suas rodagens das últimas \(weeks) semanas ficam em \(kilometers(share.base))."
    }

    static func optionalRationale(meters: Double) -> String {
        "Rodagem opcional de \(kilometers(meters)), 70% da rodagem da semana, e conta no volume. Só entra se a prontidão da manhã estiver em 60 ou mais."
    }

    static func raceRationale(target: TrainerTarget, pace: Double?) -> String {
        let goal = pace.map { " Pace de prova \(self.pace($0))/km." } ?? ""
        return "Dia da prova: \(target.name).\(goal)"
    }

    static let raceWeekEasy = "Semana da prova: rodagem curta para soltar as pernas."

    static func phaseName(_ phase: TrainerPhase) -> String {
        switch phase {
        case .base: "base"
        case .build: "construção"
        case .specific: "específico"
        case .taper: "polimento"
        }
    }

    static func phasesList(_ phases: [TrainerPhase]) -> String {
        var seen: [TrainerPhase] = []
        for phase in phases where !seen.contains(phase) { seen.append(phase) }
        return seen.map(phaseName).joined(separator: ", ")
    }
}
