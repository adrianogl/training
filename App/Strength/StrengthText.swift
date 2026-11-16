import Insights
import TrainingCore

enum StrengthText {
    static let title = "Força"
    static let today = "Força de hoje"
    static let todaySource = "Força · do seu professor"
    static let open = "abrir ›"
    static let week = "Semana"
    static let weekMuscles = "Músculos da semana"
    static let history = "Histórico"
    static let fromCoach = "do seu professor · no relógio"
    static let seeWorkout = "ver treino ›"
    static let seeVolume = "volume por grupo ›"
    static let seeSessions = "ver sessões ›"
    static let noToday = "Sem força agendada para hoje."
    static let noWeek = "Nenhuma força agendada nesta semana."
    static let noSessions = "Nenhuma sessão de força ainda. Elas chegam da Garmin depois que o relógio sincroniza."
    static let signInHint = "Entre com a conta Garmin em Ajustes para ver o treino do professor."
    static let workoutTitle = "Treino de hoje"
    static let workoutSubtitle = "Montado pelo seu professor · já está no relógio"
    static let inOrder = "Na ordem do professor"
    static let sessionTitle = "Sessão"
    static let doneVsPlanned = "Feito × planejado"
    static let workedMuscles = "O que você trabalhou"
    static let repsNote = "Repetições contadas pelo relógio; podem faltar."
    static let noSets = "As séries desta sessão ainda não chegaram da Garmin."
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
    static let weekdays = ["seg", "ter", "qua", "qui", "sex", "sáb", "dom"]
    static let back = "costas"

    static func restLabel(_ seconds: Double?) -> String {
        guard let seconds else { return "em sequência" }
        return "descanso \(Int(seconds)) s"
    }

    static func setsLabel(_ block: Int, detail: String?) -> String {
        "\(block) × \(detail ?? "")"
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

    static func doneLabel(done: Int, planned: Int) -> String {
        "\(done) de \(planned)"
    }

    static func weekday(_ day: Day) -> String {
        weekdays[day.weekStart.days(until: day)]
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
