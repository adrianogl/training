import Foundation

enum ActivityExclusionConstants {
    static let fileName = "activity-exclusions.json"
    static let blobId = "activityExclusions"
    static let syncedStampKey = "activityExclusionsSynced"
    static let activityPathFormat = "/activity-service/activity/%lld"
    static let deleteTitle = "Excluir treino"
    static let deleteSymbol = "trash"
    static let confirmTitle = "Excluir este treino?"
    static let confirmApp = "Sai do app nos seus aparelhos e das contas de carga, semana e evolução. O sync não traz ele de volta. No Garmin Connect, ele continua."
    static let confirmGarmin = "Este treino foi gravado pelo trAIning Força. Ele sai do app nos seus aparelhos e também é apagado no Garmin Connect. Não dá para desfazer."
    static let cancel = "Cancelar"
    static let garminFailed = "Não consegui apagar no Garmin Connect. Nada foi excluído; tente de novo."
    static let noGarmin = "Entre na conta Garmin em Ajustes para apagar este treino no Garmin Connect."
}
