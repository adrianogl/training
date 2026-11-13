import Foundation
import os

enum RemoteSyncSettingsConstants {
    static let logger = Logger(subsystem: "trAIning", category: "RemoteSync")
    static let keyLength = 43
    static let sectionAnchor = "remoteSync"
    static let sectionTitle = "Sincronização entre aparelhos"
    static let offDescription = "Desligada. Provas e respostas do \"Parece prova?\" ficam só neste aparelho."
    static let activate = "Ativar neste aparelho"
    static let haveKey = "Já tenho uma chave de outro aparelho"
    static let privacyNote = "O servidor guarda só dados cifrados aqui. Ele não lê nome de prova, meta nem GPX."
    static let activating = "Ativando…"
    static let activateFailed = "Não ativou. Confira a conexão e tente de novo."
    static let synced = "Sincronizado"
    static let syncing = "Sincronizando…"
    static let neverSynced = "ainda não sincronizou"
    static let racesLabel = "Provas"
    static let decisionsLabel = "Respostas do \"Parece prova?\""
    static let syncNow = "Sincronizar agora"
    static let keySectionTitle = "Chave de sync"
    static let showKey = "Mostrar chave"
    static let hideKey = "Esconder chave"
    static let showKeyHint = "Face ID"
    static let copyKey = "Copiar chave"
    static let keyCopied = "Chave copiada. Ela some da área de transferência em 2 minutos e não passa para os outros aparelhos sozinha: mande para você mesmo por AirDrop ou mensagem, ou digite no outro aparelho."
    static let noPasscode = "Este aparelho não tem código de bloqueio, então o app não mostra nem copia a chave. Ative o código em Ajustes do iPhone › Face ID e Código."
    static let clipboardLifetime: TimeInterval = 120
    static let keyNote = "Cole essa chave no outro aparelho, em Ajustes. Quem tiver a chave lê e altera as suas provas."
    static let revealReason = "Mostrar a chave de sincronização"
    static let copyReason = "Copiar a chave de sincronização"
    static let disable = "Desligar neste aparelho"
    static let disableTitle = "Desligar a sincronização neste aparelho?"
    static let disableMessage = "As provas continuam neste aparelho e no servidor. Para ligar de novo, cole a chave."
    static let deleteServer = "Apagar dados do servidor"
    static let deleteServerTitle = "Apagar os dados do servidor?"
    static let deleteServerMessage = "As provas e respostas guardadas no servidor somem e a sincronização desliga. Os dados deste aparelho ficam. Os outros aparelhos vão mostrar \"chave não encontrada\"."
    static let deleteServerConfirm = "Apagar do servidor"
    static let deleteServerFailed = "Não apagou do servidor. Confira a conexão e tente de novo."
    static let cancel = "Cancelar"
    static let pasteTitle = "Colar chave"
    static let pasteHint = "No outro aparelho, abra Ajustes › Sincronização entre aparelhos › Copiar chave e cole aqui."
    static let pastePlaceholder = "Chave de sync"
    static let pasteSection = "Ao conectar"
    static let localRacesLabel = "Provas neste aparelho"
    static let mergeLabel = "Ficam junto com as do servidor"
    static let mergeValue = "sim"
    static let mergeNote = "Nenhuma prova é apagada. Se a mesma prova foi editada nos dois, fica a edição mais recente."
    static let connect = "Conectar"
    static let connecting = "Conectando…"
    static let keyEmpty = "Cole a chave copiada do outro aparelho."
    static let keyCharacters = "A chave só tem letras, números, - e _. Confira se copiou só a chave, sem espaços no meio."
    static let keyMalformed = "Essa chave não é válida. Copie de novo no outro aparelho."
    static let keyNotFoundOnServer = "Essa chave não existe no servidor. Confira se copiou do aparelho certo ou se os dados do servidor foram apagados."
    static let noConnection = "Sem conexão com o servidor. Tente de novo quando a rede voltar."
    static let problemKeyNotFound = "Sync recusado: chave não encontrada"
    static let problemBusy = "Sync adiado: servidor ocupado"
    static let problemUnreadable = "Sync parado: dados do servidor não abrem com esta chave"
    static let problemOther = "Sync entre aparelhos falhou"
    static let problemQuota = "Sync parado: espaço do servidor esgotado"
    static let quotaHint = "O servidor não aceita mais dados desta conta. As mudanças ficam neste aparelho. Apague provas antigas com GPX ou os dados do servidor e ative de novo."
    static let accountLimit = "O servidor não está aceitando contas novas agora. Tente de novo mais tarde."

    static func keyLength(_ count: Int) -> String {
        "A chave tem \(keyLength) caracteres e esta tem \(count). Confira se copiou inteira."
    }

    static func tooLarge(_ count: Int) -> String {
        count == 1 ? "1 prova grande demais para sincronizar" : "\(count) provas grandes demais para sincronizar"
    }

    static func relative(_ date: Date, now: Date = .now) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: now)
    }

    static func waiting(_ count: Int) -> String {
        count == 1 ? "1 mudança esperando rede" : "\(count) mudanças esperando rede"
    }

    static func problem(_ problem: RemoteSyncProblem) -> String {
        switch problem {
        case .keyNotFound: problemKeyNotFound
        case .busy: problemBusy
        case .quotaExceeded: problemQuota
        case .unreadable: problemUnreadable
        case .other: problemOther
        }
    }
}
