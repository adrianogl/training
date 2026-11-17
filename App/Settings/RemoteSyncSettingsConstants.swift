import Foundation
import os

enum RemoteSyncSettingsConstants {
    static let logger = Logger(subsystem: "trAIning", category: "RemoteSync")
    static let sectionTitle = "Sincronização"
    static let accountNote = "Tudo o que você cadastra aparece nos aparelhos em que você entrar com esta conta."
    static let synced = "Sincronizado"
    static let syncing = "Sincronizando…"
    static let neverSynced = "ainda não sincronizou"
    static let syncNow = "Sincronizar agora"
    static let showKeyHint = "Face ID"
    static let clipboardLifetime: TimeInterval = 120
    static let cancel = "Cancelar"
    static let watchSectionTitle = "Relógio"
    static let watchNeedsSync = "Ligue a sincronização entre aparelhos para gerar o token do relógio."
    static let watchOffDescription = "Gere um token para o mostrador TrainingFace mostrar a prontidão de hoje."
    static let watchGenerate = "Gerar token do relógio"
    static let watchGenerating = "Gerando…"
    static let watchRegenerate = "Gerar outro"
    static let watchRegenerateTitle = "Gerar outro token?"
    static let watchRegenerateMessage = "O token atual para de funcionar. Cole o novo no mostrador."
    static let watchShow = "Mostrar token"
    static let watchHide = "Esconder token"
    static let watchCopy = "Copiar token"
    static let watchRevoke = "Revogar"
    static let watchRevokeTitle = "Revogar o token do relógio?"
    static let watchRevokeMessage = "O mostrador volta a mostrar \"--\" na prontidão até você gerar outro token."
    static let watchInstructions = "No app Garmin Connect, abra o mostrador TrainingFace > Configurações e cole o token em Token do relógio."
    static let watchTokenCopied = "Token copiado. Ele some da área de transferência em 2 minutos. Cole no app Garmin Connect, em TrainingFace > Configurações > Token do relógio."
    static let watchRevoked = "Token revogado. O mostrador para de receber a prontidão."
    static let watchGenerateFailed = "Não gerou o token. Confira a conexão e tente de novo."
    static let watchRevokeFailed = "Não revogou o token. Confira a conexão e tente de novo."
    static let watchNoPasscode = "Este aparelho não tem código de bloqueio, então o app não mostra nem copia o token. Ative o código em Ajustes do iPhone › Face ID e Código."
    static let watchRevealReason = "Mostrar o token do relógio"
    static let watchCopyReason = "Copiar o token do relógio"
    static let watchNote = "O token só lê os dados do mostrador, como a prontidão do dia e os próximos eventos da agenda. Ele não acessa a chave de sync."
    static let connect = "Conectar"
    static let connecting = "Conectando…"
    static let problemKeyNotFound = "Sync recusado: entre na conta de novo"
    static let problemBusy = "Sync adiado: servidor ocupado"
    static let problemUnreadable = "Sync parado: dados do servidor não abrem com esta chave"
    static let problemOther = "Sync entre aparelhos falhou"
    static let problemQuota = "Sync parado: espaço do servidor esgotado"
    static let quotaHint = "O servidor não aceita mais dados desta conta. As mudanças ficam neste aparelho. Apague provas antigas com GPX ou os dados do servidor e ative de novo."


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
