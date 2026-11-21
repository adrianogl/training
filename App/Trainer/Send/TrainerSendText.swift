import Foundation
import TrainingCore

enum TrainerSendText {
    static let openButton = "Enviar ao Garmin…"
    static let title = "Enviar ao Garmin"
    static let windowLabel = "Próximos 7 dias"
    static let empty = "Nada para enviar nesses dias."
    static let runFromAdvisory = "A corrida vem da assessoria. Ligue \"Corrida do treinador\" quando passar a seguir o treinador."
    static let runToggle = "Enviar as corridas do plano"
    static let autoLabel = "Envio automático"
    static let autoHint = "Ligado, o app manda sozinho quando o plano mudar: os próximos 7 dias e, com o MFIT ligado, os treinos do professor até o fim da prescrição."
    static let onlyApp = "Só treinos criados pelo app são trocados ou apagados no Garmin."
    static let needsLogin = "Entre na conta Garmin em Ajustes para enviar."
    static let statusNew = "novo"
    static let statusChanged = "mudou"
    static let statusCurrent = "no Garmin"
    static let removedOne = "1 treino que saiu do plano será apagado do Garmin."
    static let removedFormat = "%d treinos que saíram do plano serão apagados do Garmin."
    static let sendOne = "Enviar 1 treino"
    static let sendFormat = "Enviar %d treinos"
    static let runSection = "Corrida do treinador"
    static let upToDate = "Tudo já está no Garmin"
    static let sending = "Enviando…"
    static let resultFormat = "%d enviado(s), %d apagado(s)"
    static let failedFormat = ", %d com erro"
    static let close = "Fechar"
    static let mfitSection = "MFIT"
    static let mfitToggle = "Enviar os treinos do MFIT"
    static let mfitOffCaption = "Manda os treinos do professor até o fim da prescrição."
    static let mfitHint = "Exercício do professor sem par no catálogo da Garmin vai com o nome dele, como exercício livre. Se o professor mudar o programa, os treinos já enviados são trocados."
    static let mfitChip = "MFIT"

    static func mfitCaption(end: Day, count: Int) -> String {
        "Até o fim da prescrição: \(TrainerText.dayMonth(end)) · \(count == 1 ? "1 treino" : "\(count) treinos")"
    }

    static func windowLabel(mfitEnd: Day?) -> String {
        mfitEnd.map { "Próximos 7 dias e MFIT até \(TrainerText.dayMonth($0))" } ?? windowLabel
    }
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

    static func sendTitle(_ count: Int) -> String {
        count == 1 ? sendOne : String(format: sendFormat, count)
    }

    static func removed(_ count: Int) -> String {
        count == 1 ? removedOne : String(format: removedFormat, count)
    }
}
