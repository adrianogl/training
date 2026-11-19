import Foundation

enum StrengthCatalogLoader {
    private struct Row: Decodable {
        let id: String
        let nome: String
        let categoria: String
        let exercicio: String
        let padrao: MovementPattern
        let equipamento: StrengthEquipment
        let focos: Set<TrainerStrengthGroup>
        let regioes: Set<BodyRegion>
        let unilateral: Bool
        let isometria: Bool
    }

    static func decode(_ json: String) -> [CatalogExercise] {
        guard let rows = try? JSONDecoder().decode([Row].self, from: Data(json.utf8)) else { return [] }
        return rows.map {
            CatalogExercise(
                id: $0.id, name: $0.nome, category: $0.categoria, exerciseName: $0.exercicio, pattern: $0.padrao,
                focus: $0.focos, equipment: $0.equipamento, loads: $0.regioes, unilateral: $0.unilateral, timed: $0.isometria
            )
        }
    }
}
