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

    static func methodTitle(_ method: TrainerMethod) -> String {
        switch method {
        case .cruiseIntervals: "Cruise intervals"
        case .tempo: "Tempo run"
        case .intervals: "Intervalado em pace I"
        case .repetition: "Repetições em pace R"
        case .racePace: "Ritmo específico"
        case .goalPace: "Extensão do ritmo específico"
        }
    }

    static func methodSource(_ method: TrainerMethod) -> String {
        switch method {
        case .racePace: "Canova, Pfitzinger"
        case .goalPace: "Canova"
        default: "Daniels"
        }
    }

    static func methodLabel(_ method: TrainerMethod) -> String {
        let base = "\(methodTitle(method)) (\(methodSource(method)))"
        return method == .cruiseIntervals ? "\(base) com volume de limiar do método norueguês" : base
    }

    static func distance(_ meters: Double) -> String {
        meters >= 1_000 ? kilometers(meters) : "\(Int(meters.rounded())) m"
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

    static func stageLabel(_ blockMeters: Double) -> String {
        blockMeters > 0 ? "Blocos de \(kilometers(blockMeters))" : "Contínuo"
    }

    static func sessionLabel(_ blocks: [TrainerQualityBlock]) -> String {
        blocks.map { $0.repeats > 1 ? "\($0.repeats) × \(distance($0.meters))" : distance($0.meters) }.joined(separator: " + ")
    }

    static func title(kind: TrainerDayKind, meters: Double, session: TrainerQualitySession? = nil) -> String {
        let label = session.map { sessionLabel($0.blocks) }
        let thresholdName = session?.method == .racePace ? "Ritmo de prova" : "Limiar"
        let vo2Name = session?.method == .goalPace ? "Pace-alvo" : "VO2 máx"
        return switch kind {
        case .threshold: "\(thresholdName) \(label ?? kilometers(meters))"
        case .vo2max: "\(vo2Name) \(label ?? kilometers(meters))"
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

    static func createdSummary(weeks: Int, target: String, phases: String, goal: String? = nil, blockStart: Day? = nil) -> String {
        var text = "Plano de \(weeks) semanas para \(target): \(phases). O detalhe treino a treino cobre os próximos 15 dias."
        if let blockStart { text += " \(blockStartsOn(blockStart))" }
        return goal.map { "\(text) \($0)" } ?? text
    }

    static func blockStartsOn(_ day: Day) -> String { "Bloco específico começa em \(date(day))." }

    static func createdSkeleton(weeks: Int) -> String {
        "Esqueleto de \(weeks) semanas calculado com o volume inicial, o volume de pico e o maior longão dos últimos 30 dias."
    }

    static func peakShortfall(requested: Double, reached: Double) -> String {
        "O tempo até a prova não dá para chegar aos \(kilometers(requested)) com segurança; o pico fica em \(kilometers(reached))."
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
    static func distantWeekChanged(_ index: Int, count: Int) -> String {
        "Semana \(index): \(count) \(count == 1 ? "treino mudou" : "treinos mudaram")"
    }

    static let manualPaceBasis = "Pace definido por você."
    static let editedByYou = "Treino editado por você."
    static let editedKeptTitle = "Treino editado mantido"
    static let editedKept = "Seu treino editado foi mantido."
    static let editedRevertedReason = "Você voltou à sugestão do treinador."
    static let editTargetTitle = "Meta"

    static func editedPlanSummary(_ fields: [String]) -> String {
        fields.isEmpty ? "Plano editado por você." : "Plano editado por você: \(fields.joined(separator: ", "))."
    }

    static func editedWorkoutSummary(_ day: Day) -> String { "Treino de \(dayLabel(day)) editado por você." }

    static func editedSwapSummary(_ first: Day, _ second: Day) -> String {
        "Treinos de \(dayLabel(first)) e \(dayLabel(second)) trocados por você."
    }

    static func editedRevertSummary(_ day: Day) -> String { "Treino de \(dayLabel(day)) voltou à sugestão do treinador." }

    static func editedPaceTitle(_ kind: TrainerPaceKind) -> String {
        switch kind {
        case .easy: "Pace da rodagem"
        case .long: "Pace do longão"
        case .threshold: "Pace do limiar"
        case .vo2max: "Pace do VO2 máx"
        case .race: "Pace da prova"
        }
    }

    static func editedPaceReason(manual: Bool) -> String {
        manual ? "Você definiu o pace manualmente." : "Você voltou ao pace do histórico."
    }

    static let editedByYouReason = "Plano editado por você."
    static let editFieldTarget = "meta"
    static let editFieldVolumes = "volumes"
    static let editFieldStructure = "estrutura"
    static let editFieldStrength = "força"
    static let editFieldLong = "longão"
    static let editFieldPaces = "paces"

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

    static func qualityMiss(_ miss: TrainerQualityMiss) -> String {
        "O \(kindName(miss.kind).lowercased()) de \(date(miss.day)) ficou fora do alvo em \(miss.total - miss.onTarget) de \(miss.total) trechos. O próximo desce uma etapa e a recuperação sobe 200 m."
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
        case .manual:
            return manualPaceBasis
        case .prediction, .history, nil:
            return predicted.map { "Pace do 10 km previsto em \(clock($0)) mais 8 s/km." } ?? history
        }
    }

    static func vo2Basis(_ paces: TrainerPaces, predicted: Double?) -> String {
        switch paces.vo2Source {
        case .work:
            return "Pace de \(pace(paces.vo2max))/km, a mediana dos blocos dos seus últimos \(paces.vo2WorkRuns ?? 0) treinos de VO2."
        case .manual:
            return manualPaceBasis
        case .prediction, .history, .fallback, nil:
            return predicted.map { "Pace do 5 km previsto em \(clock($0))." } ?? "Pace 15 s/km abaixo do limiar, sem previsão de 5 km."
        }
    }

    static func methodRule(_ session: TrainerQualitySession, restSeconds: Double) -> String {
        let label = sessionLabel(session.blocks)
        let volume = kilometers(session.blocks.reduce(0) { $0 + Double($1.repeats) * $1.meters })
        let rest = restClock(restSeconds)
        switch session.method {
        case .cruiseIntervals:
            let shape = session.blocks.count > 1 ? "Pirâmide \(label)" : "Cruise intervals de \(distance(session.blocks[0].meters))"
            return "\(shape) (Daniels), 60 s parado por km de bloco. Volume de \(volume) em blocos, como no método norueguês."
        case .tempo:
            return "Tempo run de \(label) (Daniels), \(rest) parado entre os blocos: 60 s por km de bloco, no máximo 4 min. Volume de \(volume)."
        case .intervals:
            return "Intervalado em pace I (Daniels): \(label), descanso de \(rest) parado, 0,7 da duração do tiro. Fecha com 3 × 200 m em pace R (Daniels), com 200 m de trote entre eles."
        case .racePace:
            return "Ritmo específico (Canova, Pfitzinger): \(label) no pace da prova, descanso de \(rest) parado. Entra no lugar do limiar uma semana sim, outra não, e cresce até cerca de 70% da prova em contínuo."
        case .repetition:
            return "Repetições em pace R (Daniels)."
        case .goalPace:
            return "Extensão do ritmo específico (Canova): \(label) no pace-alvo."
        }
    }

    static func qualityRationale(
        kind: TrainerDayKind, title: String, session: TrainerQualitySession, week: TrainerWeek, previousStatus: TrainerDayStatus?,
        miss: TrainerQualityMiss?, basis: String, restSeconds: Double, goal: TrainerGoalPaceNote? = nil
    ) -> String {
        if let goal { return goalPaceRationale(title: title, session: session, restSeconds: restSeconds, note: goal) }
        let name = kindName(kind)
        if let miss {
            return "\(name) uma etapa abaixo. Descanso de \(restClock(restSeconds)) parado, 1 min a mais porque o último ficou fora do alvo em \(miss.total - miss.onTarget) de \(miss.total) trechos. \(basis)"
        }
        let rule = methodRule(session, restSeconds: restSeconds)
        let phase = phaseName(week.phase)
        let recovery = week.isRecovery ? " Semana de recuperação, volume menor." : ""
        let done = previousStatus == .done ? " O último treino saiu no alvo." : ""
        return "\(title) na semana \(week.index) (\(phase)).\(recovery)\(done) \(rule) \(basis)"
    }

    static func goalPaceRationale(
        title: String, session: TrainerQualitySession, restSeconds: Double, note: TrainerGoalPaceNote
    ) -> String {
        let blocks = sessionLabel(session.blocks)
        let rest = session.blocks[0].repeats > 1 ? ", \(restClock(restSeconds)) parado" : ""
        var text = "Pace-alvo \(blocks) a \(pace(note.pace))\(rest)."
        switch note.previousClosed {
        case true?: text += " O anterior fechou no alvo, então o bloco cresce."
        case false?: text += " O anterior não fechou no alvo, então a sessão repete."
        case nil: text += " Primeira sessão no pace-alvo: a progressão só sobe quando a anterior fecha no alvo."
        }
        if let shortfall = note.shortfall { text += " \(shortfall)" }
        return text
    }

    static func goalPaceShortfall(reached: Double, target: Double) -> String {
        "No ritmo da progressão, o pace-alvo chega a \(kilometers(reached)) até o prazo, abaixo dos \(kilometers(target)) da meta."
    }

    static func goalPaceLong(meters: Double, from: Double, to: Double) -> String {
        "Últimos \(kilometers(meters)) progressivos, do pace do longão (\(pace(from))/km) até \(pace(to))/km, o pace-alvo mais 18 s."
    }

    static func thresholdNeed(current: Double, goal: Double, meters: Double, needed: Double) -> String {
        "Hoje seu limiar é \(pace(current)); \(pace(goal)) por \(kilometers(meters)) pede ~\(pace(needed))."
    }

    static func lightWeekMarked(_ start: Day, meters: Double, displaced: [Day]) -> String {
        var text = "Semana de \(date(start)) marcada como leve: \(kilometers(meters))."
        if let first = displaced.first {
            let days = displaced.map(date).joined(separator: ", ")
            text += displaced.count == 1 ? " A recuperação de \(date(first)) virou semana normal." : " As recuperações de \(days) viraram semanas normais."
        }
        return text
    }

    static func lightWeekCleared(_ start: Day, meters: Double, added: [Day]) -> String {
        var text = "Semana de \(date(start)) voltou ao normal: \(kilometers(meters))."
        if !added.isEmpty { text += " Recuperação automática em \(added.map(date).joined(separator: ", "))." }
        return text
    }

    static let noNote = "sem observação"

    static func strengthGroupName(_ group: TrainerStrengthGroup) -> String {
        switch group {
        case .upper: "Superiores"
        case .lower: "MMII"
        case .fullBody: "Full body"
        case .core: "Core"
        }
    }

    static let strengthSummary = "Treinos de força atualizados. A corrida não muda por causa deles."

    static func longRationale(week: TrainerWeek, previousLong: Double?, cap: Double, note: String?) -> String {
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
        case .general: "base geral"
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

extension TrainerEngineText {
    static func number(_ meters: Double) -> String {
        kilometers(meters).replacingOccurrences(of: " km", with: "")
    }

    static func blocksLabel(_ blocks: [Double]) -> String {
        guard blocks.count > 1 else { return kilometers(blocks.first ?? 0) }
        if let first = blocks.first, blocks.allSatisfy({ abs($0 - first) < 1 }) {
            return "\(blocks.count) × \(kilometers(first))"
        }
        return blocks.map(number).joined(separator: " + ") + " km"
    }

    static func longStageLabel(blocks: [Double], rest: Double?) -> String {
        guard let rest, blocks.count > 1 else { return "contínuo, \(kilometers(blocks.reduce(0, +)))" }
        return "\(blocksLabel(blocks)), \(restSummary(rest))"
    }

    static func longBlocksTitle(_ meters: Double) -> String {
        "Longão \(kilometers(meters)) em blocos"
    }

    static func longStageName(stage: Int, blocks: [Double], rest: Double?) -> String {
        "etapa \(stage) de \(TrainerEngineConstants.longStageCount) · \(longStageLabel(blocks: blocks, rest: rest))"
    }

    static func longEvidence(count: Int, km: Int, longest: Double) -> String {
        let head = count > 1
            ? "Seus últimos \(count) longões tiveram pausa ou queda de pace depois do km \(km)."
            : "Um dos seus últimos longões teve pausa ou queda de pace depois do km \(km)."
        return longest < Double(km) * 1_000 ? "\(head) Blocos de até \(kilometers(longest)) terminam antes disso." : head
    }

    static func longBlocksRule(stage: Int, blocks: [Double], rest: Double?) -> String {
        "Etapa \(stage) de \(TrainerEngineConstants.longStageCount): \(longStageLabel(blocks: blocks, rest: rest)). Os 2 primeiros km de cada bloco saem 5 s/km acima do pace do longão."
    }

    static func longNextStage(remaining: Int, next: Int, blocks: [Double], rest: Double?, fewerPauses: Bool) -> String {
        let closing = remaining > 1 ? "Fechando este e o próximo" : "Fechando este"
        let effect = fewerPauses ? "tira uma pausa" : next == TrainerEngineConstants.longStageCount ? "vira contínuo" : "muda a última pausa"
        return "\(closing), a etapa \(next) \(effect): \(longStageLabel(blocks: blocks, rest: rest))."
    }

    static let longModeTitle = "Longão"
    static let longContinuousSuggestion = "Etapa 6 fechada duas vezes. Já dá para trocar o longão para contínuo na tela do plano."
    static let longContinuousNext = "Fechando este e o próximo, o plano sugere trocar o longão para contínuo."

    static func longModeChanged(to mode: TrainerLongMode, stage: Int, blocks: [Double], rest: Double?) -> String {
        switch mode {
        case .blocks:
            return "O longão passa a ser em blocos, na \(longStageName(stage: stage, blocks: blocks, rest: rest))."
        case .continuous:
            return "O longão volta a ser contínuo, sem pausas paradas."
        }
    }

    static func longModeSummary(_ mode: TrainerLongMode, stage: Int, blocks: [Double], rest: Double?) -> String {
        mode == .blocks ? "Em blocos · \(longStageName(stage: stage, blocks: blocks, rest: rest))" : "Contínuo"
    }

    static func longClosed(_ day: Day, missing: Int, next: Int) -> String {
        "O longão de \(date(day)) fechou nas pausas previstas. Falta \(missing) para a etapa \(next)."
    }

    static func longAdvanced(_ day: Day, to stage: Int) -> String {
        "O longão de \(date(day)) fechou pela segunda vez seguida. O plano sobe para a etapa \(stage)."
    }

    static func longMissed(_ day: Day, reasons: [String], back: Int?) -> String {
        var text = "O longão de \(date(day)) não fechou: \(reasons.joined(separator: ", "))."
        if let back { text += " O plano volta para a etapa \(back)." }
        return text
    }

    static let longMissShort = "distância abaixo de 90%"
    static let longMissPauses = "pausa fora do previsto"

    static func longMissFade(_ km: Int) -> String {
        "queda de pace no km \(km)"
    }

    static func longClosedLast(_ day: Day, missing: Int) -> String {
        "O longão de \(date(day)) fechou sem pausas. Falta \(missing) para o plano sugerir o contínuo."
    }

    static func longContinuousRule(_ meters: Double) -> String {
        "Etapa \(TrainerEngineConstants.longStageCount) de \(TrainerEngineConstants.longStageCount): contínuo, \(kilometers(meters))."
    }
}

extension TrainerEngineText {
    static func readinessReason(_ score: Int) -> String { "Trocado pela prontidão (\(score))." }

    static func readinessEasyRationale(_ score: Int) -> String {
        "Prontidão \(score) hoje: rodagem leve no lugar do treino forte."
    }

    static func readinessSummary(_ score: Int, swapped: Bool) -> String {
        swapped
            ? "Prontidão \(score): rodagem leve hoje e o treino forte amanhã."
            : "Prontidão \(score): rodagem leve hoje, o resto da semana fica como está."
    }
}
