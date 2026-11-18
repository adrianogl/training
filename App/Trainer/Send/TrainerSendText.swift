import Foundation

enum TrainerSendText {
    static let openButton = "Enviar ao Garmin…"
    static let title = "Enviar ao Garmin"
    static let windowLabel = "Próximos 7 dias"
    static let empty = "Nada para enviar nesses dias."
    static let runFromAdvisory = "A corrida vem da assessoria. Ligue \"Corrida do treinador\" quando passar a seguir o treinador."
    static let runToggle = "Corrida do treinador"
    static let autoLabel = "Envio automático"
    static let autoHint = "Ligado, o app manda sozinho quando o plano mudar, sempre para os próximos 7 dias."
    static let onlyApp = "Só treinos criados pelo app são trocados ou apagados no Garmin."
    static let needsLogin = "Entre na conta Garmin em Ajustes para enviar."
    static let statusNew = "novo"
    static let statusChanged = "mudou"
    static let statusCurrent = "no Garmin"
    static let removedFormat = "%d treino(s) que saíram do plano serão apagados do Garmin."
    static let sendFormat = "Enviar %d treino(s)"
    static let upToDate = "Tudo já está no Garmin"
    static let sending = "Enviando…"
    static let resultFormat = "%d enviado(s), %d apagado(s)"
    static let failedFormat = ", %d com erro"
    static let close = "Fechar"
    static let appleTitle = "Enviar ao Apple Watch"
    static let appleOpenButton = "Enviar ao Apple Watch…"
    static let appleOnlyApp = "Os treinos aparecem no app Exercício, em Treinos personalizados, no dia certo. A força vai com a duração; os exercícios ficam no iPhone."
    static let appleStatusCurrent = "no relógio"
    static let appleUpToDate = "Tudo já está no relógio"

    static func filterName(_ filter: TrainerSendFilter) -> String {
        switch filter {
        case .run: "Corrida"
        case .strength: "Força"
        case .both: "Os dois"
        }
    }

    static func autoName(_ filter: TrainerSendFilter?) -> String {
        switch filter {
        case nil: "Desligado"
        case .run: "Só corrida"
        case .strength: "Só força"
        case .both: "Os dois"
        }
    }

    static func status(_ status: TrainerSendStatus) -> String {
        switch status {
        case .new: statusNew
        case .changed: statusChanged
        case .current: statusCurrent
        }
    }
}
