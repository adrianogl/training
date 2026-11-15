import Foundation
import Insights
import TrainingCore
import WorkoutAnalysis

enum TrainerText {
    private typealias C = TrainerConstants

    static let title = "Treinador"
    static let beta = "BETA"
    static let cardCreate = "Criar plano"
    static let emptyTitle = "Nenhum plano ainda"
    static let emptyBody = "O treinador monta duas semanas de treino por distância, com a estrutura da sua semana, e revê o plano a cada semana e depois de treinos fora do previsto."
    static let upcoming = "Semanas"
    static let weeksLabel = "Até a prova"
    static let askButton = "Pedir readequação"
    static let updatedBanner = "Plano atualizado"
    static let updatedAction = "ver o que mudou ›"
    static let deleteMenu = "Apagar plano"
    static let deleteTitle = "Apagar o plano do treinador?"
    static let deleteConfirm = "Apagar plano"
    static let deleteMessage = "O plano e as versões anteriores saem do aparelho. Os treinos feitos continuam no app."
    static let cancel = "Cancelar"
    static let done = "Concluir"
    static let phases: [(TrainerPhase, String)] = [
        (.general, "base geral"), (.base, "base"), (.build, "construção"), (.specific, "específico"), (.taper, "polimento"),
    ]
    static let restTitle = "Folga"
    static let raceCell = "prova"
    static let recoveryWeek = "recup."
    static let longRun = "longão"
    static let changedStatus = "mudou"
    static let doneStatus = "feito ✓"
    static let onTargetStatus = "no alvo"
    static let offTargetStatus = "fora do alvo"
    static let missedStatus = "não feito"
    static let skippedStatus = "pulado"
    static let todayStatus = "hoje"
    static let trot = "trote"
    static let goalPaceLabel = "Pace-alvo"
    static let trotTitle = "Trote"
    static let methodPrefix = "Método"
    static let paceDistanceTarget = "Pace por distância"
    static let distanceLabel = "Distância-alvo"
    static let lightWeeksTitle = "Semanas leves"
    static let lightWeeksHint = "Uma semana leve vira recuperação e o ciclo de 4 semanas recomeça a partir dela."
    static let markLight = "Marcar como semana leve"
    static let unmarkLight = "Desmarcar semana leve"
    static let lightCell = "semana leve"
    static let restStepTitle = "Descanso parado"
    static let restBeforeNextTitle = "Descanso antes da próxima série"
    static let longBlockPauseTitle = "Pausa parada · água e gel"
    static let longModeTitle = "Longão"
    static let longModeHint = "Em blocos, o longão tem pausas curtas para beber e tomar gel, e os blocos crescem até ele ficar contínuo."
    static let bestTimeTitle = "Melhor horário"
    static let bestTimeCaption = "previsão do dia"
    static let whyTitle = "Por que este treino"
    static let numbersTitle = "Números"
    static let doneTitle = "O que você fez"
    static let structureTitle = "Estrutura"
    static let editPlanMenu = "Editar plano"
    static let editPlanTitle = "Editar plano"
    static let save = "Salvar"
    static let saveEditButton = "Salvar e refazer daqui pra frente"
    static let previewTitle = "O que vai mudar"
    static let previewEmpty = "Nada muda no plano."
    static let editedStatus = "editado"
    static let paceFromHistory = "do histórico"
    static let paceManual = "manual"
    static let paceAdjust = "Ajustar"
    static let paceBackToHistory = "Do histórico"
    static let paceRaceName = "Prova"
    static let paceGoalName = "Pace-alvo"
    static let paceLongName = "Longão"
    static let paceEasyName = "Rodagem"
    static let editWorkoutButton = "Editar"
    static let editWorkoutTitle = "Editar treino"
    static let seriesTitle = "Série"
    static let workoutEditTitle = "Treino"
    static let repeatsLabel = "Repetições"
    static let blockLabel = "Bloco"
    static let restLabel = "Descanso parado"
    static let totalDistanceLabel = "Distância"
    static let swapTitle = "Trocar de dia"
    static let editGridHint = "Toque num dia para trocar o tipo."
    static let swapEmpty = "Não há outro dia livre nesta semana para trocar."
    static let swapHint = "Escolha outro dia para trocar os dois treinos de lugar."
    static let revertButton = "↺ Voltar à sugestão do treinador"

    static func paceKindName(_ kind: TrainerPaceKind, goal: Bool) -> String {
        switch kind {
        case .easy: paceEasyName
        case .long: paceLongName
        case .threshold: "Limiar"
        case .vo2max: "VO2 máx"
        case .race: goal ? paceGoalName : paceRaceName
        }
    }

    static func previewLines(_ changes: [TrainerChange]) -> [String] {
        let lines = changes.filter { $0.kind != .unchanged && $0.kind != .newWeek }.map { change -> String in
            guard let before = change.before, let after = change.after else { return change.title }
            return "\(change.title): \(before) → \(after)"
        }
        guard lines.count > C.previewLineLimit else { return lines }
        return Array(lines.prefix(C.previewLineLimit)) + ["e mais \(lines.count - C.previewLineLimit)"]
    }

    static func editHeading(_ workout: TrainerWorkout) -> String {
        "\(kindName(workout.kind)) · \(C.weekdayFull[weekday(workout.day)]), \(workout.day.day)"
    }

    static func editTotal(total: Double, warmup: Double?) -> String {
        guard let warmup, warmup > 0 else { return "Total: \(distance(total))." }
        return "Total: \(distance(total)) com \(distance(warmup)) de aquecimento."
    }

    static func swapChip(_ day: Day) -> String {
        "\(weekdayShort(day)) \(day.day)"
    }
    static let plannedLabel = "Planejado"
    static let paceLabel = "Pace"
    static let notePrefix = "Observação"
    static let runDistance = "Distância"
    static let runPace = "Pace médio"
    static let runHeartRate = "FC média"
    static let runOnTarget = "Blocos no alvo"
    static let runPauses = "Pausas"
    static let runFade = "Queda no km"
    static let changesTitle = "O que mudou"
    static let versionsTitle = "Versões"
    static let currentVersion = "atual"
    static let noChanges = "Esta versão não alterou treinos."
    static let requestTitle = "Pedir readequação"
    static let requestWhy = "Por que você quer readequar?"
    static let requestPlaceholder = "Conte o que está acontecendo."
    static let requestFrom = "A partir de"
    static let requestUntil = "Até"
    static let requestUntilToggle = "Tem data para acabar"
    static let requestSubmit = "Readequar o plano"
    static let requestWorking = "Readequando..."
    static let requestResult = "Plano readequado"
    static let newPlanTitle = "Novo plano"
    static let targetRace = "Prova-alvo"
    static let targetText = "Meta em texto"
    static let raceLabel = "Prova"
    static let noRaces = "Nenhuma prova cadastrada. Cadastre uma em Provas ou use a meta em texto."
    static let textLabel = "Meta"
    static let textPlaceholder = "Ex.: fechar o longão de 18 km sem parar"
    static let deadlineToggle = "Tem prazo"
    static let deadlineLabel = "Prazo"
    static let weekGridTitle = "Semana"
    static let pacesTitle = "Paces do seu histórico"
    static func paceSource(_ name: String, pace: Double, source: TrainerPaceSource?, runs: Int?, work: String) -> String? {
        guard source == .work, let runs else { return nil }
        return "\(name) \(WorkoutFormat.clock(pace))/km, a mediana dos blocos dos seus últimos \(runs) \(work)."
    }
    static let thresholdName = "Limiar"
    static let vo2Name = "VO2"
    static let thresholdRuns = "limiares"
    static let vo2Runs = "treinos de VO2"
    static let startTitle = "Km para começar"
    static let peakTitle = "Km no pico"
    static let weeklyHint = "A rodagem opcional conta no volume."
    static func weeklyAverage(_ kilometers: Int) -> String { "Sua média das últimas 4 semanas: \(kilometers) km" }
    static func weeklyValue(_ kilometers: Int) -> String { "\(kilometers) km" }
    static func volumeSummary(start: Int, peak: Int, weeks: Int, dated: Bool) -> String {
        guard peak > start else {
            return dated ? "Mantém \(start) km, com recuperação a cada 4 semanas." : "Mantém \(start) km em ciclos de 4 semanas."
        }
        let rise = "Sobe de \(start) para \(peak) km em \(weeks) semanas, com recuperação a cada 4"
        return dated ? "\(rise)." : "\(rise), e depois mantém em ciclos de 4 semanas."
    }
    static let paceEasy = "rodagem"
    static let paceThreshold = "limiar"
    static let paceVo2 = "VO2 máx"
    static let createButton = "Criar plano até a prova"
    static let createTextButton = "Criar plano"
    static let creating = "Criando..."
    static let saveError = "Não deu para salvar o plano neste aparelho."
    static let goalFormat = "meta %@"
    static let strengthTitle = "Treinos de força"
    static let strengthCardEmpty = "Cadastre a musculação para ver os dias de força no plano."
    static let strengthWeekTitle = "Sua semana de força"
    static let strengthSource = "da Garmin · 4 semanas"
    static let strengthEmpty = "Nenhuma sessão cadastrada."
    static let strengthAdd = "+ Adicionar sessão"
    static let strengthEditTitle = "Editar sessão"
    static let strengthNewTitle = "Nova sessão"
    static let strengthRemove = "Remover sessão"
    static let strengthSave = "Salvar"
    static let strengthDayLabel = "Dia"
    static let strengthGroupLabel = "Grupo"
    static let strengthNameLabel = "Nome"
    static let strengthNone = "Sem força"
    static let strengthNote = "O treinador não muda a musculação, e a corrida não muda por causa dela."
    static let strengthGridHint = "A força vem do que a Garmin mostrou nas últimas 4 semanas. Toque para ajustar."

    static func kindName(_ kind: TrainerDayKind) -> String {
        switch kind {
        case .easy: "Rodagem"
        case .threshold: "Limiar"
        case .vo2max: "VO2 máx"
        case .optionalEasy: "Opcional"
        case .long: "Longão"
        case .off: "Folga"
        case .race: "Prova"
        }
    }

    static func kindShort(_ kind: TrainerDayKind) -> String {
        switch kind {
        case .easy: "Rod."
        case .threshold: "Limiar"
        case .vo2max: "VO2"
        case .optionalEasy: "Opc."
        case .long: "Longão"
        case .off: "Folga"
        case .race: "Prova"
        }
    }

    static func categoryTitle(_ category: TrainerRequestCategory) -> String {
        C.shortcuts.first { $0.category == category }?.title ?? "Pedido"
    }

    static func kilometersNumber(_ meters: Double) -> String {
        WorkoutFormat.kilometers(meters).replacingOccurrences(of: ",0", with: "")
    }

    static func distance(_ meters: Double) -> String {
        if meters < 1_000 { return "\(Int(meters.rounded())) m" }
        return "\(kilometersNumber(meters)) km"
    }

    static func pace(_ secondsPerKm: Double) -> String {
        "\(WorkoutFormat.clock(secondsPerKm))/km"
    }

    static func paceRange(low: Double?, high: Double?) -> String? {
        switch (low, high) {
        case (nil, nil):
            return nil
        case let (value?, nil), let (nil, value?):
            return pace(value)
        case let (low?, high?):
            let fast = min(low, high)
            let slow = max(low, high)
            if Int(fast.rounded()) == Int(slow.rounded()) { return pace(fast) }
            return "\(WorkoutFormat.clock(fast))–\(WorkoutFormat.clock(slow))/km"
        }
    }

    static func weekday(_ day: Day) -> Int {
        day.weekStart.days(until: day)
    }

    static func weekdayShort(_ day: Day) -> String {
        C.weekdayShort[weekday(day)]
    }

    static func dayMonth(_ day: Day) -> String {
        "\(day.day) \(C.monthShort[day.month - 1])"
    }

    static func dayMonth(_ date: Date) -> String {
        dayMonth(Day.today(now: date))
    }

    static func longDate(_ day: Day) -> String {
        "\(C.weekdayFull[weekday(day)]), \(day.day) de \(C.monthFull[day.month - 1])"
    }

    static func dateOnly(_ day: Day) -> String {
        "\(day.day) de \(C.monthFull[day.month - 1])"
    }

    static func dateOnly(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.wide).locale(C.locale))
    }

    static func weekTitle(index: Int?, start: Day) -> String {
        let end = start.adding(days: C.weekdayCount - 1)
        let range = start.month == end.month ? "\(start.day) a \(end.day) \(C.monthShort[end.month - 1])" : "\(dayMonth(start)) a \(dayMonth(end))"
        guard let index else { return "Semana de \(range)" }
        return "Semana \(index) · \(range)"
    }

    static func weekCaption(plannedMeters: Double?) -> String {
        guard let plannedMeters else { return "" }
        return "\(kilometersNumber(plannedMeters)) km"
    }

    static func methodLine(_ method: TrainerMethod) -> String {
        "\(methodPrefix): \(method.title) (\(method.source))"
    }

    static func paceGoalName(pace: Int, kilometers: Int) -> String {
        "\(WorkoutFormat.clock(Double(pace)))/km até \(kilometers) km"
    }

    static func goalCaption(plan: TrainerPlan, weeks: Int?) -> String {
        var parts: [String] = []
        if let pace = plan.target.goalPace, plan.target.kind == .paceDistance { parts.append("meta \(WorkoutFormat.clock(pace))/km") }
        if let seconds = plan.target.goalSeconds { parts.append(String(format: goalFormat, WorkoutFormat.clock(seconds))) }
        if let weeks { parts.append("\(weeks) \(weeks == 1 ? "semana" : "semanas")") }
        parts.append("versão \(plan.versions.last?.number ?? 1)")
        return parts.joined(separator: " · ")
    }

    static func targetTitle(_ target: TrainerTarget) -> String {
        guard let date = target.date else { return target.name }
        return "\(target.name) · \(dateOnly(date))"
    }

    static func goalGlyph(_ target: TrainerTarget) -> String {
        guard target.kind == .race, let meters = target.distanceMeters, meters > 0 else { return "★" }
        return String(Int((meters / 1_000).rounded()))
    }

    static func stepRows(_ workout: TrainerWorkout) -> [TrainerStepRow] {
        if let rows = longBlockRows(workout) { return rows }
        let steps = workout.steps
        var rows: [TrainerStepRow] = []
        var index = 0
        while index < steps.count {
            let step = steps[index]
            let next = index + 1 < steps.count ? steps[index + 1] : nil
            if step.kind == .work, step.repeats > 1, let next, next.kind == .recovery, next.repeats == step.repeats - 1 {
                rows.append(TrainerStepRow(id: rows.count, kind: step.kind, title: seriesTitle(step.repeats), detail: "", isHeader: true))
                rows.append(row(step, at: index, in: workout, single: true, id: rows.count, isNested: true))
                rows.append(row(next, at: index + 1, in: workout, single: true, id: rows.count, isNested: true))
                index += 2
                if index < steps.count, steps[index].repeats <= 1, let rest = steps[index].restSeconds, rest == next.restSeconds {
                    index += 1
                }
            } else {
                rows.append(row(step, at: index, in: workout, single: false, id: rows.count))
                index += 1
            }
        }
        return rows
    }

    private static func longBlockRows(_ workout: TrainerWorkout) -> [TrainerStepRow]? {
        guard workout.kind == .long, workout.steps.contains(where: { $0.kind == .recovery && $0.restSeconds != nil }) else { return nil }
        var blocks: [(steps: [TrainerStep], rest: Double?)] = []
        var current: [TrainerStep] = []
        for step in workout.steps {
            if step.kind == .recovery, let rest = step.restSeconds {
                blocks.append((current, rest))
                current = []
            } else {
                current.append(step)
            }
        }
        blocks.append((current, nil))
        var rows: [TrainerStepRow] = []
        func append(_ kind: TrainerStepKind, title: String, detail: String, isHeader: Bool = false, isNested: Bool = false) {
            rows.append(TrainerStepRow(id: rows.count, kind: kind, title: title, detail: detail, isHeader: isHeader, isNested: isNested))
        }
        func appendBlock(_ block: [TrainerStep], isNested: Bool) {
            let meters = block.reduce(0.0) { $0 + $1.meters * Double($1.repeats) }
            let lows = block.compactMap(\.paceLow)
            let highs = block.compactMap(\.paceHigh)
            var detail = distance(meters)
            if let range = paceRange(low: lows.min(), high: highs.max()) { detail += " · \(range)" }
            append(.steady, title: kindStepName(.long), detail: detail, isNested: isNested)
        }
        func appendPause(_ rest: Double, isNested: Bool) {
            append(.recovery, title: longBlockPauseTitle, detail: restClock(rest), isNested: isNested)
        }
        var index = 0
        while index < blocks.count {
            var end = index
            while end + 1 < blocks.count, blocks[end + 1].steps == blocks[index].steps { end += 1 }
            let count = end - index + 1
            if count > 1, let rest = blocks[index].rest {
                append(.work, title: seriesTitle(count), detail: "", isHeader: true)
                appendBlock(blocks[index].steps, isNested: true)
                appendPause(rest, isNested: true)
            } else {
                appendBlock(blocks[index].steps, isNested: false)
                if let rest = blocks[end].rest { appendPause(rest, isNested: false) }
            }
            index = end + 1
        }
        return rows
    }

    private static func row(_ step: TrainerStep, at index: Int, in workout: TrainerWorkout, single: Bool, id: Int, isNested: Bool = false) -> TrainerStepRow {
        let steps = workout.steps
        let repeats = single ? 1 : step.repeats
        if let rest = step.restSeconds {
            let isTransition = !isNested && step.repeats <= 1 && index + 1 < steps.count && steps[index + 1].kind == .work
            let title = isTransition ? restBeforeNextTitle : repeated(repeats, restStepTitle)
            return TrainerStepRow(id: id, kind: step.kind, title: title, detail: restClock(rest), isNested: isNested)
        }
        if step.kind == .recovery && step.meters > 0 && step.paceLow == nil {
            return TrainerStepRow(id: id, kind: step.kind, title: repeated(repeats, trotTitle), detail: distance(step.meters), isNested: isNested)
        }
        var detail = distance(step.meters)
        if let range = paceRange(low: step.paceLow, high: step.paceHigh) {
            detail += " · \(range)"
        } else if step.kind == .recovery {
            detail += " · \(trot)"
        }
        var single = step
        single.repeats = repeats
        return TrainerStepRow(id: id, kind: step.kind, title: stepTitle(single, in: workout), detail: detail, isNested: isNested)
    }

    static func longModeName(_ mode: TrainerLongMode) -> String {
        mode == .blocks ? "Em blocos" : "Contínuo"
    }

    static func longSuggestion(_ suggestion: TrainerLongSuggestion) -> String {
        "Sugerido: pausas ou queda de pace em \(suggestion.flagged) dos últimos \(suggestion.total) longões."
    }

    static func longStageCaption(stage: Int, streak: Int) -> String {
        let count = TrainerEngine.longStageCount
        if stage >= count { return "etapa \(stage) de \(count) · \(streak + 1)º de \(TrainerEngine.longStageAdvanceStreak) para o contínuo" }
        return "etapa \(stage) de \(count) · \(streak + 1)º de \(TrainerEngine.longStageAdvanceStreak) para avançar"
    }

    static func bestTimeStart(_ hour: Int) -> String {
        "Sair às \(hour)h"
    }

    static func temperature(_ value: Double) -> String {
        "\(Int(value.rounded())) °C"
    }

    static func heatWarning(_ heat: TrainerHeat, hasBlocks: Bool) -> String {
        let limit = temperature(TrainerHeat.threshold)
        let pace = "o pace sobe \(Int(heat.paceOffset)) s/km"
        return hasBlocks
            ? "Mesmo no horário mais fresco passa de \(limit): \(pace) e os blocos ficam 1 km menores."
            : "Mesmo no horário mais fresco passa de \(limit): \(pace)."
    }

    static func heatLater(hour: Int, hasBlocks: Bool) -> String {
        let limit = temperature(TrainerHeat.threshold)
        return hasBlocks
            ? "A partir das \(hour)h passa de \(limit). Com calor, o pace sobe 5 a 10 s/km e os blocos ficam 1 km menores."
            : "A partir das \(hour)h passa de \(limit). Com calor, o pace sobe 5 a 10 s/km."
    }

    static func seriesTitle(_ repeats: Int) -> String {
        "\(repeats)×"
    }

    static func repeated(_ repeats: Int, _ title: String) -> String {
        repeats > 1 ? "\(repeats)× \(title)" : title
    }

    static func stepTitle(_ step: TrainerStep, in workout: TrainerWorkout) -> String {
        switch step.kind {
        case .warmup: return "Aquecimento"
        case .cooldown: return "Desaquecimento"
        case .recovery: return "Recuperação"
        case .steady: return "Ritmo constante"
        case .work:
            let name: String
            switch step.method {
            case .repetition: name = "Repetição R"
            case .goalPace: name = "Pace-alvo"
            case .racePace: name = "Ritmo de prova"
            default: name = kindStepName(workout.kind)
            }
            return step.repeats > 1 ? "\(step.repeats)× \(name)" : name
        }
    }

    static func kindStepName(_ kind: TrainerDayKind) -> String {
        switch kind {
        case .threshold: "Limiar"
        case .vo2max: "VO2 máx"
        case .long: "Longão"
        default: "Trabalho"
        }
    }

    static func restClock(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static func shapeBars(_ steps: [TrainerStep]) -> [TrainerShapeBar] {
        var bars: [TrainerShapeBar] = []
        func append(_ kind: TrainerStepKind, _ meters: Double, isRest: Bool = false) {
            if kind == .steady, !isRest, let last = bars.last, last.kind == .steady, !last.isRest {
                bars[bars.count - 1] = TrainerShapeBar(id: last.id, kind: kind, meters: last.meters + meters, isRest: false)
                return
            }
            bars.append(TrainerShapeBar(id: bars.count, kind: kind, meters: meters, isRest: isRest))
        }
        var index = 0
        while index < steps.count {
            let step = steps[index]
            let next = index + 1 < steps.count ? steps[index + 1] : nil
            if step.kind == .work, step.repeats > 1, let next, next.kind == .recovery {
                for repeatIndex in 0..<step.repeats {
                    append(.work, step.meters)
                    if repeatIndex < step.repeats - 1 { append(.recovery, next.meters, isRest: next.restSeconds != nil) }
                }
                index += 2
            } else {
                for _ in 0..<max(step.repeats, 1) { append(step.kind, step.meters, isRest: step.restSeconds != nil) }
                index += 1
            }
        }
        return bars
    }

    static func status(for row: TrainerDayRow) -> TrainerStatusLabel? {
        guard row.workout.kind != .off else { return nil }
        switch row.status {
        case .done:
            if let onTarget = row.run?.activeOnTarget, let total = row.run?.activeTotal, total > 0, onTarget == total {
                return TrainerStatusLabel(text: onTargetStatus, tone: .good)
            }
            return TrainerStatusLabel(text: doneStatus, tone: .good)
        case .partial:
            return TrainerStatusLabel(text: distance(row.run?.meters ?? 0), tone: .attention)
        case .offTarget:
            return TrainerStatusLabel(text: offTargetStatus, tone: .attention)
        case .missed:
            return TrainerStatusLabel(text: missedStatus, tone: .bad)
        case .skipped:
            return TrainerStatusLabel(text: skippedStatus, tone: .dim)
        case .today:
            return TrainerStatusLabel(text: todayStatus, tone: .good)
        case .planned:
            return row.isChanged ? TrainerStatusLabel(text: changedStatus, tone: .attention) : nil
        }
    }

    static func runPace(_ run: TrainerRun) -> String? {
        guard run.meters > 0, run.seconds > 0 else { return nil }
        return pace(run.seconds / (run.meters / 1_000))
    }

    static func triggerText(_ trigger: TrainerTrigger) -> String {
        switch trigger {
        case .created: "plano criado"
        case .weekEnded(let index): "fim da semana \(index)"
        case .workout(_, let day): "depois do treino de \(C.weekdayFull[weekday(day)])"
        case .request: "pedido por você"
        case .strengthChanged: "treinos de força atualizados"
        case .lightWeek(let day): "semana de \(dayMonth(day)) alterada"
        case .longModeChanged: "modo do longão alterado"
        case .readiness(_, let score): "prontidão \(score)"
        case .edited(let edit): edit.days.isEmpty ? "plano editado por você" : "treino editado por você"
        }
    }

    static func versionTitle(_ version: TrainerVersion) -> String {
        "Versão \(version.number) · \(dateOnly(version.createdAt))"
    }

    static func groupName(_ group: TrainerStrengthGroup) -> String {
        switch group {
        case .upper: "Superiores"
        case .lower: "MMII"
        case .fullBody: "Full body"
        case .core: "Core"
        }
    }

    static func groupShort(_ group: TrainerStrengthGroup) -> String {
        switch group {
        case .upper: "Sup."
        case .lower: "MMII"
        case .fullBody: "Full"
        case .core: "Core"
        }
    }

    static func strengthCaption(done: Int, minutes: Int?) -> String {
        var text = "\(done) de \(C.strengthWeeks) semanas"
        if let minutes { text += " · ~\(minutes) min" }
        return text
    }

    static func strengthTag(_ line: TrainerStrengthLine) -> String {
        line.isDone ? "✓ \(line.name)" : "+ \(line.name)"
    }

    static func strengthSummary(_ sessions: [TrainerStrengthSession]) -> String {
        sessions.sorted { $0.weekday < $1.weekday }
            .map { "\(C.weekdayShort[$0.weekday - 1].capitalized) \($0.name)" }
            .joined(separator: " · ")
    }

    static func weekdayName(_ index: Int) -> String {
        C.weekdayShort[index]
    }
}
