import Foundation
import Insights

enum ExerciseDetailText {
    static let question = "A imagem mostra a execução certa?"
    static let matches = "✓ Corresponde"
    static let doesNotMatch = "✕ Não corresponde"
    static let confirmedFormat = "Confirmada por você em %@"
    static let undo = "Desfazer"
    static let alternativesQuestion = "Alguma destas mostra o movimento?"
    static let searchWger = "Buscar na wger"
    static let useDrawing = "Usar o desenho"
    static let noneMatched = "Nenhuma imagem serviu."
    static let tellDifference = "Conte o que está diferente:"
    static let saveSuggestion = "Salvar sugestão"
    static let suggestionSaved = "Sugestão salva"
    static let savedHint = "Salvo no aparelho · enviado na sincronização"
    static let notesTitle = "Observações"
    static let addNote = "+ Adicionar"
    static let noteLabel = "Observação"
    static let cancel = "Cancelar"
    static let save = "Salvar"
    static let edit = "Editar"
    static let delete = "Apagar"
    static let chosen = "Você escolheu esta imagem"
    static let chosenFormat = "em %@. Vale já neste aparelho."
    static let rejectedFormat = "Marcada como não corresponde em %@"
    static let pageFormat = "%d de %d"
    static let saveFailed = "Não salvou. Tente de novo."
    static let noAlternatives = "Sem outras imagens deste movimento aqui."
    static let mfitLabel = "MFIT · só leitura"
    static let suggestedPill = "sugerida"
    static let perHand = "por mão"
    static let publicDomain = "free-exercise-db · domínio público"
    static let wger = "wger"
    static let drawingFormat = "Desenho · padrão %@"
    static let stepsTitle = "Passo a passo"
    static let carouselLabel = "Imagens do exercício; arraste para o lado"
    static let photoLabel = "Foto do exercício"
    static let openFormat = "Abrir %@"

    static func header(_ input: ExerciseDetailInput) -> String {
        [input.dose, input.load, input.rest].compactMap { $0 }.joined(separator: " · ")
    }

    static func shortDate(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.day, .month], from: date)
        return String(format: "%02d/%02d", parts.day ?? 0, parts.month ?? 0)
    }

    static func page(_ index: Int, of total: Int) -> String {
        String(format: pageFormat, index + 1, total)
    }

    static func credit(_ media: ExerciseMedia, pattern: MovementPattern?) -> String {
        switch media.source {
        case .freeExerciseDb:
            return publicDomain
        case .wger:
            return ([wger] + [media.author, media.license].compactMap { $0 }).joined(separator: " · ")
        case .drawing:
            return String(format: drawingFormat, (media.pattern ?? pattern).map(patternName) ?? "")
        }
    }

    static func patternName(_ pattern: MovementPattern) -> String {
        switch pattern {
        case .squat: "agachamento"
        case .hinge: "dobradiça de quadril"
        case .singleLeg: "unilateral de perna"
        case .calf: "panturrilha"
        case .hipStability: "estabilidade do quadril"
        case .plyo: "pliometria"
        case .horizontalPush: "empurrar na horizontal"
        case .horizontalPull: "puxar na horizontal"
        case .verticalPush: "empurrar na vertical"
        case .verticalPull: "puxar na vertical"
        case .antiExtension: "antiextensão do tronco"
        case .antiRotation: "antirrotação do tronco"
        case .lateralCore: "core lateral"
        case .mobilityHip: "mobilidade do quadril"
        case .mobilityAnkle: "mobilidade do tornozelo"
        case .mobilityThoracic: "mobilidade torácica"
        }
    }
}
