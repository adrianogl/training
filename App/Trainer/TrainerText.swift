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
    static let upcoming = "Próximos 15 dias"
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
        (.base, "base"), (.build, "construção"), (.specific, "específico"), (.taper, "polimento"),
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
    static let restStepTitle = "Descanso parado"
    static let whyTitle = "Por que este treino"
    static let numbersTitle = "Números"
    static let doneTitle = "O que você fez"
    static let structureTitle = "Estrutura"
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
    static let strengthCardEmpty = "Cadastre a musculação para a corrida se ajustar em volta dela."
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
    static let strengthLoadLabel = "Peso para as pernas"
    static let strengthNameLabel = "Nome"
    static let strengthNone = "Sem força"
    static let strengthNote = "O treinador não muda a musculação. Ele ajusta a corrida em volta dela."
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
        return "planejado \(kilometersNumber(plannedMeters)) km"
    }

    static func goalCaption(plan: TrainerPlan, weeks: Int?) -> String {
        var parts: [String] = []
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

    static func summaryLine(_ workout: TrainerWorkout) -> String {
        var parts: [String] = []
        if let range = paceRange(low: workout.paceLow, high: workout.paceHigh) { parts.append(range) }
        if let note = workout.note, !note.isEmpty { parts.append(note) }
        return parts.joined(separator: " · ")
    }

    static func stepRows(_ workout: TrainerWorkout) -> [TrainerStepRow] {
        workout.steps.enumerated().map { index, step in
            if let rest = step.restSeconds {
                return TrainerStepRow(id: index, kind: step.kind, title: restStepTitle, detail: restClock(rest))
            }
            var detail = distance(step.meters)
            if let range = paceRange(low: step.paceLow, high: step.paceHigh) {
                detail += " · \(range)"
            } else if step.kind == .recovery {
                detail += " · \(trot)"
            }
            return TrainerStepRow(id: index, kind: step.kind, title: stepTitle(step, in: workout), detail: detail)
        }
    }

    static func stepTitle(_ step: TrainerStep, in workout: TrainerWorkout) -> String {
        switch step.kind {
        case .warmup: return "Aquecimento"
        case .cooldown: return "Desaquecimento"
        case .recovery: return "Recuperação"
        case .steady: return "Ritmo constante"
        case .work:
            let name: String
            switch workout.kind {
            case .threshold: name = "Limiar"
            case .vo2max: name = "VO2 máx"
            case .long: name = "Longão"
            default: name = "Trabalho"
            }
            return step.repeats > 1 ? "\(step.repeats)× \(name)" : name
        }
    }

    static func restClock(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static func shapeBars(_ steps: [TrainerStep]) -> [TrainerShapeBar] {
        var bars: [TrainerShapeBar] = []
        func append(_ kind: TrainerStepKind, _ meters: Double, isRest: Bool = false) {
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

    static func loadName(_ load: TrainerStrengthLoad) -> String {
        load == .heavy ? "pesado" : "leve"
    }

    static func legsLoad(_ load: TrainerStrengthLoad) -> String {
        "pernas \(loadName(load))"
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
