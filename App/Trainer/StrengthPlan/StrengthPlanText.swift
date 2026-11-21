import Foundation
import Insights
import TrainingCore

enum StrengthPlanText {
    static let newTitle = "Novo plano de força"
    static let editTitle = "Editar plano"
    static let cancel = "Cancelar"
    static let objectiveTitle = "Objetivo"
    static let daysTitle = "Dias"
    static let addDay = "+ Adicionar dia"
    static let validityTitle = "Validade"
    static let durationLabel = "Duração"
    static let startLabel = "Começa em"
    static let untilLabel = "Termina em"
    static let raceLabel = "Prova"
    static let builderTitle = "Quem monta"
    static let builderHint = "Claude: o pedido usa a validade do plano no lugar de \"próxima semana\"."
    static let create = "Criar plano"
    static let save = "Salvar plano"
    static let cardLabel = "Plano de força"
    static let editPlan = "Editar plano"
    static let newPlan = "+ Novo plano de força"
    static let nextPlan = "Montar próximo plano"
    static let repeatPlan = "Repetir o mesmo plano"
    static let endPlan = "Encerrar plano"
    static let endConfirmTitle = "Encerrar o plano agora?"
    static let endConfirmBody = "Os dias dele deixam de gerar treino. O MFIT continua igual."
    static let endConfirm = "Encerrar"
    static let endKeep = "Voltar"
    static let adjust = "Ajustar"
    static let ok = "Ok"
    static let mfitLabel = "MFIT"
    static let mfitTeacher = "professor"
    static let mfitUnchanged = "não muda com o plano"
    static let mfitSame = "continua igual"
    static let claudeSavedTitle = "Plano salvo"
    static let claudeSavedBody = "Peça ao Claude os treinos dos dias do plano."
    static let noDays = "Adicione pelo menos um dia."
    static let strengthLabel = "Força"
    static let labelSeparator = "·"
    static let exercisesFormat = "%d exercícios"
    static let weekFormat = "semana %d de %d"

    static func objectiveName(_ objective: StrengthObjective) -> String {
        switch objective {
        case .mobility: "Mobilidade"
        case .strength: "Força"
        case .prevention: "Prevenção"
        }
    }

    static func objectiveHint(_ objective: StrengthObjective) -> String {
        switch objective {
        case .mobility: "Mobilidade: quadril, tornozelo e torácica, sem carga."
        case .strength: "Força: foco que você escolher, intensidade moderada."
        case .prevention: "Prevenção: corpo todo leve, com unilateral, panturrilha e quadril."
        }
    }

    static func validityName(_ mode: StrengthPlanValidityMode) -> String {
        switch mode {
        case .untilRace: "Até a prova"
        case .weeks: "Semanas"
        case .untilDate: "Até a data"
        }
    }

    static func builderName(_ builder: StrengthPlanBuilder) -> String {
        switch builder {
        case .trainer: "Treinador"
        case .claude: "Claude"
        }
    }

    static func weeks(_ count: Int) -> String {
        count == 1 ? "1 semana" : "\(count) semanas"
    }

    static func shortDate(_ day: Day) -> String {
        String(format: "%02d/%02d", day.day, day.month)
    }

    static func weekdayDate(_ day: Day) -> String {
        "\(TrainerText.weekdayShort(day)). \(shortDate(day))"
    }

    static func summary(end: Day, planned: Int) -> String {
        "Termina \(weekdayDate(end)) · \(planned) treinos"
    }

    static func raceValue(_ race: TrainerRaceOption) -> String {
        "\(race.name) · \(shortDate(race.day))"
    }

    static func sessionLine(_ session: TrainerStrengthSession) -> String {
        "\(TrainerStrengthText.focusName(session.group)) · \(TrainerStrengthText.placeName(session.place).lowercased())"
    }

    static func minutes(_ value: Int) -> String {
        String(format: TrainerStrengthText.minutesFormat, value)
    }

    static func dayShort(_ weekday: Int) -> String {
        TrainerText.weekdayName(weekday - 1).capitalized
    }

    static func cardTitle(_ plan: StrengthPlan) -> String {
        "\(objectiveName(plan.objective)) · \(join(weekdays(plan.weekdays).map { TrainerText.weekdayName($0 - 1) }))"
    }

    static func cardPeriod(_ plan: StrengthPlan) -> String {
        var parts = ["\(shortDate(plan.start)) a \(shortDate(plan.end))"]
        let minutes = Set(plan.sessions.map(\.minutes))
        if minutes.count == 1, let value = minutes.first { parts.append(self.minutes(value)) }
        let places = Set(plan.sessions.map(\.place))
        if places.count == 1, let place = places.first { parts.append(TrainerStrengthText.placeName(place).lowercased()) }
        return parts.joined(separator: " · ")
    }

    static func claudeFocusChanged(built: TrainerStrengthGroup, plan: TrainerStrengthGroup) -> String {
        "Montado para \(TrainerStrengthText.focusName(built).lowercased()). O plano agora pede \(TrainerStrengthText.focusName(plan).lowercased())."
    }

    static func startsOn(_ day: Day) -> String {
        "\(startLabel) \(weekdayDate(day))"
    }

    static func progress(week: Int, weeks: Int, done: Int, planned: Int) -> String {
        "Semana \(week) de \(weeks) · \(done) de \(planned) treinos feitos"
    }

    static func endedTitle(_ objective: StrengthObjective, end: Day) -> String {
        "Plano de \(objectiveName(objective).lowercased()) terminou em \(shortDate(end))"
    }

    static func endedBody(done: Int, planned: Int, weekdays: Set<Int>) -> String {
        let names = join(Self.weekdays(weekdays).map { StrengthPlanUIConstants.weekdayPlural[$0 - 1] })
        return "\(done) de \(planned) treinos feitos. \(names.prefix(1).uppercased() + names.dropFirst()) ficam sem treino do plano."
    }

    static func migration(end: Day) -> String {
        "Seu treino de força virou um plano até \(shortDate(end)). Ajuste a validade se quiser."
    }

    static func mfitTitle(_ sessions: [TrainerStrengthSession]) -> String {
        let names = sessions.sorted { $0.weekday < $1.weekday }.map(\.name).reduce(into: [String]()) { names, name in
            if !names.contains(name) { names.append(name) }
        }
        let parts = names.map { name -> (prefix: String, suffix: String) in
            guard let space = name.lastIndex(of: " ") else { return ("", name) }
            return (String(name[...space]), String(name[name.index(after: space)...]))
        }
        guard names.count > 1, let prefix = parts.first?.prefix, !prefix.isEmpty, parts.allSatisfy({ $0.prefix == prefix }) else { return join(names) }
        return prefix + join(parts.map(\.suffix))
    }

    static func mfitSubtitle(_ sessions: [TrainerStrengthSession], ended: Bool) -> String {
        "\(join(weekdays(Set(sessions.map(\.weekday))).map { TrainerText.weekdayName($0 - 1) })) · \(ended ? mfitSame : mfitUnchanged)"
    }

    static func dayPlanSubtitle(exercises: Int, week: Int?, weeks: Int) -> String {
        let count = String(format: exercisesFormat, exercises)
        guard let week else { return count }
        return "\(count) · \(String(format: weekFormat, week, weeks))"
    }

    private static func weekdays(_ set: Set<Int>) -> [Int] {
        set.sorted()
    }

    static func join(_ items: [String]) -> String {
        guard items.count > 1, let last = items.last else { return items.first ?? "" }
        return items.dropLast().joined(separator: ", ") + " e " + last
    }
}
