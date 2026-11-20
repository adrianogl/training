import Foundation
import Insights

enum TrainerStrengthText {
    static let daysTitle = "Dias de força"
    static let sourceLabel = "Fonte"
    static let focusLabel = "Foco"
    static let intensityLabel = "Intensidade"
    static let durationLabel = "Duração"
    static let placeLabel = "Onde"
    static let fromTeacher = "do professor"
    static let useSuggestion = "Usar a sugestão"
    static let suggestionTitle = "Sugestão do treinador"
    static let save = "Salvar"
    static let remove = "Tirar este dia"
    static let painButton = "Algum desconforto?"
    static let painTitle = "Algum desconforto?"
    static let painHint = "O treinador evita exercícios que carregam a região até você desmarcar."
    static let swapButton = "Trocar"
    static let swapTitleFormat = "Trocar %@"
    static let swapNone = "Sem alternativa para esse exercício com o local e a dor marcados."
    static let use = "Usar"
    static let cancel = "Cancelar"
    static let keepOriginal = "Manter original"
    static let ok = "Ok"
    static let replacedFormat = "trocado por você · era %@"
    static let restLabel = "Sem força hoje"
    static let mfitReadOnly = "Os dias do MFIT vêm do professor e não são editados aqui."
    static let minutesFormat = "%d min"
    static let exercisesFormat = "%d exercícios"
    static let upcomingTitle = "Próximos treinos de força"
    static let upcomingEmpty = "Nenhum dia do treinador nos próximos 7 dias."
    static let noPlanNote = "Sem plano do treinador, os dias de corrida forte vêm dos treinos do Garmin (assessoria). Semana de recuperação e prova só entram com plano."
    static let weekTitle = "Força da semana"
    static let openStrength = "Abrir força"
    static let mfitDaysFormat = "%@ vêm do MFIT."
    static let runPlanTitle = "Plano de corrida"
    static let runPlanBody = "Sua corrida vem do Garmin. Crie um plano quando quiser que o treinador planeje a corrida também."
    static let createRunPlan = "Criar plano de corrida"
    static let shortcutStrength = "Força"
    static let shortcutSend = "Enviar ao Garmin"
    static let shortcutAdjustments = "Ajustes do plano"

    static func sourceName(_ source: TrainerStrengthSource) -> String {
        switch source {
        case .mfit: "MFIT"
        case .trainer: "Treinador"
        }
    }

    static func focusName(_ group: TrainerStrengthGroup) -> String {
        switch group {
        case .upper: "Superiores"
        case .lower: "Pernas"
        case .fullBody: "Corpo inteiro"
        case .core: "Mobilidade e core"
        }
    }

    static func intensityName(_ intensity: TrainerStrengthIntensity) -> String {
        switch intensity {
        case .light: "Leve"
        case .moderate: "Moderada"
        case .heavy: "Pesada"
        }
    }

    static func placeName(_ place: StrengthPlace) -> String {
        switch place {
        case .gym: "Academia"
        case .home: "Casa"
        case .bodyweight: "Só peso do corpo"
        }
    }

    static func regionName(_ region: BodyRegion) -> String {
        switch region {
        case .knee: "Joelho"
        case .calfAchilles: "Panturrilha e aquiles"
        case .lowerBack: "Lombar"
        case .hip: "Quadril"
        case .shoulder: "Ombro"
        }
    }

    static func caption(_ session: TrainerStrengthSession) -> String {
        guard session.source == .trainer else { return fromTeacher }
        return [intensityName(session.intensity).lowercased(), String(format: minutesFormat, session.minutes), placeName(session.place).lowercased()].joined(separator: " · ")
    }

    static func meta(_ workout: GeneratedStrengthWorkout) -> String {
        [String(format: minutesFormat, Int(workout.estimatedMinutes.rounded())), String(format: exercisesFormat, workout.exercises.count), placeName(workout.place)].joined(separator: " · ")
    }

    static func dose(_ exercise: GeneratedExercise) -> String {
        let amount = exercise.seconds.map { "\($0) s" } ?? exercise.reps.map(String.init) ?? ""
        return "\(exercise.sets) × \(amount)\(exercise.perSide ? " cada" : "")"
    }

    static func load(_ exercise: GeneratedExercise) -> String? {
        if let replaced = exercise.replacedName { return String(format: replacedFormat, replaced) }
        guard let weight = exercise.weight else { return nil }
        return "\(Int(weight.rounded())) kg"
    }

    static func adjustmentTitle(_ adjustment: StrengthAdjustment) -> String {
        switch adjustment {
        case .qualityDay: "Dia de corrida forte"
        case .recoveryWeek: "Semana de recuperação"
        case .raceWeek: "Semana da prova"
        case .raceRest: "Perto da prova"
        case .lowReadiness(let score): "Prontidão \(score) hoje"
        case .pain(let regions): "Ajustado por desconforto: " + TrainerStrengthConstants.regionOrder.filter(regions.contains).map { regionName($0).lowercased() }.joined(separator: ", ")
        }
    }

    static func adjustmentBody(_ adjustment: StrengthAdjustment) -> String {
        switch adjustment {
        case .qualityDay(let original): "Foco marcado: \(focusName(original).lowercased()). Para não cansar a perna, o treino ficou em mobilidade e core."
        case .recoveryWeek: "Menos volume esta semana: 70% das séries e da duração."
        case .raceWeek: "Até 3 dias antes da prova, só mobilidade de 15 min."
        case .raceRest: "Sem força nos 3 dias antes da prova."
        case .lowReadiness: "O treino virou mobilidade, 20 min. Volta ao normal quando a prontidão subir."
        case .pain: "Saíram os exercícios que carregam a região e entraram alternativas."
        }
    }

    static func canKeepOriginal(_ adjustment: StrengthAdjustment) -> Bool {
        switch adjustment {
        case .qualityDay, .lowReadiness: true
        default: false
        }
    }
}
