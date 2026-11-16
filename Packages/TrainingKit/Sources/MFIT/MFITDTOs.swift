import Foundation

struct MFITProgramSummaryDTO: Decodable {
    let id: Int64
    let nome: String?
    let dataInicio: String?
    let dataFim: String?
}

struct MFITProgramDTO: Decodable {
    let id: Int64
    let idUser: Int64?
    let nome: String?
    let dataInicio: String?
    let dataFim: String?
    let workouts: [MFITWorkoutRefDTO]?
}

struct MFITWorkoutRefDTO: Decodable {
    let id: Int64
    let nome: String?
    let ordenacao: Int?
    let feedback: [MFITFeedbackDTO]?
}

struct MFITFeedbackDTO: Decodable {
    let dataExecucao: String?
    let workoutStartTime: String?
    let workoutEndTime: String?
    let borgNota: Int?
}

struct MFITSessionDTO: Decodable {
    let exercs: [MFITBlockDTO]?
}

struct MFITBlockDTO: Decodable {
    let order: Int?
    let exercises: [MFITExerciseDTO]?
}

struct MFITGroupDTO: Decodable {
    let nome: String?
}

struct MFITExerciseRefDTO: Decodable {
    let name: String?
    let exerciseGroup: MFITGroupDTO?
}

struct MFITExerciseDTO: Decodable {
    let name: String?
    let isCombinado: Bool?
    let exerciseGroup: MFITGroupDTO?
    let series: [MFITSerieDTO]?
}

struct MFITSerieDTO: Decodable {
    let tipo: Int?
    let obs: String?
    let carga: Double?
    let exercicio: MFITExerciseRefDTO?

    enum CodingKeys: String, CodingKey {
        case tipo, obs, carga, exercicio
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tipo = try container.decodeIfPresent(Int.self, forKey: .tipo)
        obs = try container.decodeIfPresent(String.self, forKey: .obs)
        exercicio = try container.decodeIfPresent(MFITExerciseRefDTO.self, forKey: .exercicio)
        if let number = try? container.decodeIfPresent(Double.self, forKey: .carga) {
            carga = number
        } else if let text = try? container.decodeIfPresent(String.self, forKey: .carga) {
            carga = Double(text.replacingOccurrences(of: ",", with: "."))
        } else {
            carga = nil
        }
    }
}

struct MFITTeacherDTO: Decodable {
    let id: Int64
    let name: String?
    let lastname: String?
}

struct MFITTeachersEnvelopeDTO: Decodable {
    let data: [MFITTeacherDTO]?
}

struct MFITTokenDTO: Decodable {
    struct Nested: Decodable {
        let token: String?
    }

    let token: String?
    let data: Nested?
    let message: String?
}

struct MFITLoginBody: Encodable {
    let mail: String
    let senha: String
}

struct MFITProgressDTO: Decodable {
    struct DateDTO: Decodable {
        let year: Int
        let month: Int
        let day: Int
    }

    struct EntryDTO: Decodable {
        let data: DateDTO?
        let cargas: [Double]?
    }

    let exerciseName: String?
    let dataView: [EntryDTO]?
}
