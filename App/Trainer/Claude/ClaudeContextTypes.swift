import Foundation
import Insights
import TrainingCore

struct ClaudeRaceTarget: Equatable {
    let name: String
    let day: Day
}

struct ClaudeContextInput {
    let today: Day
    let first: Day
    let last: Day
    let trainerSessions: [TrainerStrengthSession]
    let mfit: [Int: [MovementPattern]]
    let runs: [Day: (kind: TrainerDayKind, name: String)]
    let readiness: [Day: Int]
    let pain: Set<BodyRegion>
    let loads: [String: Double]
    let race: ClaudeRaceTarget?
}

struct ClaudeContextPayload: Codable, Equatable {
    struct Period: Codable, Equatable {
        let inicio: String
        let fim: String
        let hoje: String
    }

    struct TrainerDay: Codable, Equatable {
        let dia_da_semana: String
        let foco: String
        let intensidade: String
        let minutos: Int
        let local: String
    }

    struct MFITDay: Codable, Equatable {
        let dia_da_semana: String
        let padroes: [String]
    }

    struct Run: Codable, Equatable {
        let dia: String
        let tipo: String
        let nome: String
    }

    struct Readiness: Codable, Equatable {
        let dia: String
        let nota: Int
    }

    struct Race: Codable, Equatable {
        let nome: String
        let dia: String
    }

    struct Exercise: Codable, Equatable {
        let id: String
        let nome: String
        let padrao: String
        let equipamento: String
        let regioes: [String]
        let focos: [String]
        let unilateral: Bool
        let isometria: Bool
    }

    let periodo: Period
    let prova: Race?
    let dias_do_treinador: [TrainerDay]
    let mfit: [MFITDay]
    let corrida: [Run]
    let prontidao: [Readiness]
    let dor: [String]
    let ultimas_cargas_kg: [String: Double]
    let catalogo: [Exercise]
    let regras: [String]
}
