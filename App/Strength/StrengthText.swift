import Insights
import TrainingCore
import WorkoutAnalysis

enum StrengthText {
    static let title = "Força"
    static let today = "Força de hoje"
    static let todaySource = "Força · do seu professor no MFIT"
    static let open = "abrir ›"
    static let week = "Semana"
    static let weekMuscles = "Músculos da semana"
    static let history = "Histórico"
    static let noWeek = "Nenhum treino do MFIT nesta semana."
    static let noSessions = "Nenhuma sessão de força ainda. Elas aparecem quando você conclui o treino no MFIT ou grava a força no relógio."
    static let workoutTitle = "Treino de hoje"
    static let workoutSubtitle = "Montado pelo seu professor no MFIT"
    static let inOrder = "Na ordem do professor"
    static let sessionTitle = "Sessão"
    static let sessionWorkout = "Treino do professor"
    static let workedMuscles = "O que você trabalhou"
    static let effort = "esforço"
        static let noWorkout = "Esta sessão não casou com nenhum treino do MFIT."
    static let volumeTitle = "Volume por grupo"
    static let volumeSubtitle = "Séries por semana · o número é a semana passada"
    static let historyTitle = "Sessões de força"
    static let perWeek = "sessões por semana · 12 semanas"
    static let average = "média"
    static let minutes = "min"
    static let bpm = "bpm"
    static let averageHR = "FC média"
    static let maxHR = "FC máx"
    static let sets = "séries"
    static let legend = ["poucas", "médio", "muitas séries"]
    static let off = "off"
    static let front = "frente"
    static let section = "Força"
    static let groupsTitle = "Séries por grupo · semana"
    static let groupsLink = "6 semanas ›"
    static let loadsTitle = "Evolução de carga"
    static let loadsSubtitle = "Maior carga de cada dia · do MFIT"
    static let loadsEmpty = "Nenhuma carga registrada ainda. Registre o peso das séries no MFIT e ele aparece aqui."
    static let loadsNote = "Exercícios sem carga registrada, como prancha e flexão, não entram na lista."
    static let seeAll = "ver todos ›"
    static let firstRecord = "1º registro"
    static let currentLoad = "atual"
    static let recordLoad = "recorde"
    static let records = "Registros"
    static let recordBadge = "recorde"
    static let fromWatch = "relógio"
    static let fromMFIT = "MFIT"
    static let weekdays = ["seg", "ter", "qua", "qui", "sex", "sáb", "dom"]
    static let back = "costas"

    static func restLabel(_ seconds: Double?) -> String {
        guard let seconds else { return "em sequência" }
        return "descanso \(Int(seconds)) s"
    }

    static func setsLabel(_ block: Int, detail: String?, weight: Double?) -> String {
        [detail.map { "\(block) × \($0)" } ?? "\(block) séries", weight.map(weightLabel)].compactMap { $0 }.joined(separator: " · ")
    }

    static func countLabel(exercises: Int, sets: Int) -> String {
        "\(exercises) exercícios · \(sets) séries"
    }

    static func averageLabel(_ value: Double) -> String {
        String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",")
    }

    static func weightLabel(_ kilograms: Double) -> String {
        let text = kilograms == kilograms.rounded() ? String(Int(kilograms)) : String(format: "%.1f", kilograms).replacingOccurrences(of: ".", with: ",")
        return "\(text) kg"
    }

    static func programLabel(_ title: String, start: Day?, end: Day?) -> String {
        guard let start, let end else { return title }
        return "\(title) · \(start.day)/\(start.month) a \(end.day)/\(end.month)"
    }

    static func weekday(_ day: Day) -> String {
        weekdays[day.weekStart.days(until: day)]
    }

    static func exerciseName(_ name: String) -> String {
        let stripped = name.replacingOccurrences(of: #"\([^)]*\)"#, with: " ", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard let first = stripped.first else { return name }
        return first.uppercased() + stripped.dropFirst()
    }

    static let legFactorTitle = "Força de pernas ontem"
    static let legFactorNote = "não entra na nota"

    static func legSentence(_ leg: StrengthLegDay) -> String {
        "Pernas ainda carregadas do \(leg.title) de ontem."
    }

    static func legFactorDetail(_ leg: StrengthLegDay) -> String {
        "\(leg.title) · \(leg.sets) séries, \(leg.legSets) de perna · \(legFactorNote)"
    }

    static func legIntervalsAdvice(_ leg: StrengthLegDay, slowPace: Double?, reps: Int?) -> String {
        let pace = slowPace.map { " (\(WorkoutFormat.clock($0))/km)" } ?? ""
        let fewer = reps.flatMap { $0 > 2 ? " Se sentir peso, faça \($0 - 1) tiros em vez de \($0)." : nil } ?? ""
        return "Pernas do \(leg.title) de ontem: faça o aquecimento completo e segure o 1º tiro no topo da faixa\(pace).\(fewer)"
    }

    static func legTempoAdvice(_ leg: StrengthLegDay, slowPace: Double?) -> String {
        let pace = slowPace.map { " (\(WorkoutFormat.clock($0))/km)" } ?? ""
        return "Pernas do \(leg.title) de ontem: faça o aquecimento completo e comece o 1º bloco no topo da faixa\(pace)."
    }

    static func legLongAdvice(_ leg: StrengthLegDay) -> String {
        "Pernas do \(leg.title) de ontem: comece os 3 primeiros km mais leve e só depois vá para o ritmo do longão."
    }

    static func missedLabel(_ title: String, day: Day) -> String {
        "Faltou o \(shortTitle(title)) de \(MFITAccountConstants.weekdayNames[day.weekStart.days(until: day)])"
    }

    static func reportSessions(_ summary: WeeklyStrengthSummary) -> String {
        summary.planned > 0 ? "\(summary.done) de \(summary.planned)" : "\(summary.done)"
    }

    static func reportDetail(_ summary: WeeklyStrengthSummary) -> String {
        "\(summary.planned > 0 ? "sessões do MFIT" : "sessões") · \(summary.sets) séries"
    }

    static func reportRecord(_ record: WeeklyStrengthRecord) -> String {
        "\(record.name) \(weightLabel(record.top)), +\(weightLabel(record.gain))"
    }

    static func reportNotification(_ summary: WeeklyStrengthSummary) -> String {
        var text = "Força: \(reportSessions(summary)) sessões, \(summary.sets) séries"
        if let record = summary.records.first {
            text += " e recorde no \(record.name.prefix(1).lowercased() + record.name.dropFirst()) (\(weightLabel(record.top)))"
        }
        return text + "."
    }

    static func recordTitle(_ name: String) -> String {
        "Recorde no \(name.prefix(1).lowercased() + name.dropFirst())"
    }

    static func recordText(_ series: StrengthLoadSeries, today: Day) -> String {
        guard let last = series.points.last else { return "" }
        let when = last.day == today ? "de hoje" : "de \(last.day.day)/\(last.day.month)"
        let workout = last.workout.isEmpty ? "" : " na \(last.workout) \(when)"
        guard let best = series.points.dropLast().max(by: { $0.top < $1.top }) else { return weightLabel(last.top) + workout + "." }
        return "\(weightLabel(last.top))\(workout), \(weightLabel(last.top - best.top)) acima do recorde anterior (\(weightLabel(best.top)), \(best.day.day)/\(best.day.month))."
    }

    static func changeLabel(_ change: Double) -> String {
        (change > 0 ? "+" : change < 0 ? "−" : "±") + weightLabel(abs(change))
    }

    static func sinceLabel(_ day: Day) -> String {
        "desde \(day.day)/\(day.month)"
    }

    static func recordLabel(_ day: Day) -> String {
        "\(recordLoad) · \(day.day)/\(day.month)"
    }

    static func loadsList(_ loads: [Double]) -> String {
        loads.map { weightLabel($0).replacingOccurrences(of: " kg", with: "") }.joined(separator: " · ") + " kg"
    }

    static func runLabel(_ kind: TrainerDayKind, meters: Double) -> String {
        switch kind {
        case .threshold: "Limiar"
        case .vo2max: "VO2"
        case .race: "Prova"
        default: "\(Int((meters / 1_000).rounded())) km"
        }
    }

    static func shortTitle(_ title: String) -> String {
        title.components(separatedBy: " (").first ?? title
    }

    static func groupName(_ group: MuscleGroup) -> String {
        switch group {
        case .chest: "Peito"
        case .shoulders: "Ombros"
        case .biceps: "Bíceps"
        case .triceps: "Tríceps"
        case .forearms: "Antebraço"
        case .abs: "Abdômen"
        case .obliques: "Oblíquos"
        case .traps: "Trapézio"
        case .lats: "Costas"
        case .lowerBack: "Lombar"
        case .glutes: "Glúteos"
        case .quads: "Quadríceps"
        case .hamstrings: "Posteriores"
        case .adductors: "Adutores"
        case .calves: "Panturrilha"
        }
    }

    static func dayLabel(_ day: Day) -> String {
        "\(weekday(day)), \(day.day)/\(day.month)"
    }
}
