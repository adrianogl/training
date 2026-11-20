import Foundation

enum StravaConstants {
    static let signature = "via https://training.aglv.dev"
    static let callbackScheme = "training"
    static let comparisonWindowDays = 42.0
    static let secondsPerDay = 86_400.0
    static let retryWindow: TimeInterval = 24 * 3_600
    static let retryDelay: TimeInterval = 15 * 60
    static let maxPerPass = 3
    static let ledgerDefaultsKey = "stravaSendLedger"
    static let ledgerLimit = 60
    static let paceSameSeconds = 5.0
    static let heartRateLowerDelta = 3.0
    static let paceBeatSeconds = 1.0
    static let longerBeatKm = 0.1

    static let sectionTitle = "Strava"
    static let formTitle = "Conexão"
    static let settingsSummaryOff = "Toque para conectar"
    static let statusConnected = "conectado"
    static let statusDisconnected = "desconectado"
    static let settingsSummaryOn = "Resumo ligado"
    static let settingsSummaryPaused = "Resumo desligado"
    static let connect = "Conectar com o Strava"
    static let connecting = "Conectando…"
    static let disconnect = "Desconectar"
    static let connectedFormat = "Conectado como %@"
    static let connectedAnonymous = "Conectado"
    static let toggleTitle = "Escrever o resumo nas corridas"
    static let formatTitle = "Formato"
    static let formatName = "B · resumo curto"
    static let exampleTitle = "Exemplo"
    static let example = "VO2 máx | 5 × 1 km @ 3:48/km · nota 88\nMelhor VO2 das últimas 6 semanas: 5 s/km mais rápido que em 15/10.\nvia https://training.aglv.dev"
    static let footer = "O trAIning acrescenta o resumo ao fim da descrição da corrida no Strava, depois que a nota fica pronta. Se você editar o texto dele no Strava, ele não mexe mais."
    static let unavailable = "O Strava ainda não está configurado no servidor."
    static let connectFailed = "Não conectou ao Strava. Tente de novo."
    static let connectDenied = "Você não autorizou o acesso. O trAIning precisa ler e escrever nas suas atividades."
    static let connectScope = "Marque as duas permissões na tela do Strava para conectar."
    static let statusFailed = "Não consegui consultar o Strava agora."

    static let sendButton = "Enviar ao Strava"
    static let resendButton = "Reenviar ao Strava"
    static let sent = "Enviado ao Strava"
    static let updated = "Resumo atualizado no Strava"
    static let notYet = "Ainda não chegou no Strava"
    static let editedByUser = "Você editou o texto no Strava; não mexemos"
    static let disabled = "Ligue o resumo nos ajustes do Strava"
    static let notConnected = "Conecte o Strava nos ajustes"
    static let retryLater = "O Strava limitou os pedidos. Tente em alguns minutos"
    static let sendFailed = "Não enviou ao Strava. Tente de novo"
    static let noText = "Esse treino ainda não tem dados para o resumo"

    static let kindTitles: [SessionKind: String] = [.long: "Longão", .threshold: "Limiar", .intervals: "VO2 máx", .easy: "Rodagem", .race: "Prova"]
    static let highlightNames: [SessionKind: String] = [.threshold: "limiar", .intervals: "VO2"]
    static let goalPaceTitle = "Pace-alvo"
    static let goalPaceName = "pace-alvo"
    static let goalPaceWords = ["pace-alvo", "pace alvo"]
    static let blockFormat = "%d × %@"
    static let blockSeparator = " + "
    static let setSeparator = " + "
    static let setsSharedSizeFormat = "%@ × %@"
    static let headlineFormat = "%@ | %@"
    static let scoreFormat = "%@ · nota %d"
    static let volumeFormat = "%@ km @ %@/km"
    static let blocksFormat = "%@ @ %@/km"
    static let paceBestFormat = "Melhor %@ das últimas 6 semanas: %d s/km mais rápido que em %@."
    static let longestFormat = "Maior longão das últimas 6 semanas: %@ km, %@ km a mais que em %@."
    static let heartRateFormat = "FC %d bpm mais baixa que em %@, no mesmo pace."
    static let fadeFormat = "Pace caiu a partir do km %d."
    static let dateFormat = "d/M"
}
