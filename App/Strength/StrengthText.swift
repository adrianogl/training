import Insights
import TrainingCore

enum StrengthText {
    static let title = "Força"
    static let today = "Força de hoje"
    static let todaySource = "Força · do seu professor no MFIT"
    static let open = "abrir ›"
    static let week = "Semana"
    static let weekMuscles = "Músculos da semana"
    static let history = "Histórico"
    static let fromCoach = "do seu professor · MFIT"
    static let seeWorkout = "ver treino ›"
    static let seeVolume = "volume por grupo ›"
    static let seeSessions = "ver sessões ›"
    static let noToday = "Sem força para hoje."
    static let noWeek = "Nenhum treino do MFIT nesta semana."
    static let noSessions = "Nenhuma sessão de força ainda. Elas aparecem quando você conclui o treino no MFIT ou grava a força no relógio."
    static let signInHint = "Entre com a conta MFIT em Ajustes para ver o treino do professor."
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
    static let legendShort = ["poucas", "médio", "muitas"]
    static let off = "off"
    static let front = "frente"
    static let rest = "Descanso"
    static let perWeekShort = "por semana · 12 sem"
    static let thisWeek = "nesta semana"
    static let plannedSets = "séries planejadas"
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

    static func weekLabel(sessions: Int, sets: Int) -> String {
        "\(sessions) sessões · \(sets) séries"
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

    static func runKindName(_ kind: TrainerDayKind) -> String {
        switch kind {
        case .easy, .optionalEasy: "Rodagem"
        case .threshold: "Limiar"
        case .vo2max: "VO2 máx"
        case .long: "Longão"
        case .race: "Prova"
        case .off: "Descanso"
        }
    }

    static func kilometers(_ meters: Double) -> String {
        "\(Int((meters / 1_000).rounded())) km"
    }

    static func strengthChip(_ title: String) -> String {
        "Força · \(title)"
    }

    static func todaySubtitle(exercises: Int, sets: Int) -> String {
        "do seu professor · MFIT · \(countLabel(exercises: exercises, sets: sets))"
    }

    static func sessionLine(_ session: StrengthSession) -> String {
        [dayLabel(session.day), session.effort.map { "esforço \($0)" }].compactMap { $0 }.joined(separator: " · ")
    }

    static func sessionStats(_ session: StrengthSession) -> String {
        [session.minutes.map { "\($0) \(minutes)" }, session.averageHR.map { "\($0) \(bpm)" }].compactMap { $0 }.joined(separator: " · ")
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
