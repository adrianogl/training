import Foundation

enum ComparisonText {
    static let currentLabel = "Este treino"

    static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).locale(WorkoutConstants.locale))
    }

    static let commonBlocksNotice = "A estrutura do treino mudou entre as ocorrências. A comparação usa só os blocos em comum."
    static let ownActiveBlocksNotice = "A estrutura mudou; pace e FC são a média dos blocos ativos de cada treino."
}
