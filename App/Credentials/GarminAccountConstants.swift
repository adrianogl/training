import Foundation

enum GarminAccountConstants {
    static let sectionTitle = "Conta Garmin"
    static let footer = "A senha vai para o servidor do trAIning, que entra na Garmin por você e não guarda a senha, só a sessão cifrada. Conectada uma vez, vale em todos os seus aparelhos."
    static let loginExpired = "O código venceu. Entre de novo para receber outro."
    static let emailPlaceholder = "E-mail da conta Garmin"
    static let passwordPlaceholder = "Senha"
    static let codePlaceholder = "Código de verificação"
    static let signIn = "Entrar"
    static let signingIn = "Entrando…"
    static let confirmCode = "Confirmar código"
    static let disconnect = "Desconectar"
    static let cancel = "Cancelar"
    static let disconnectTitle = "Desconectar o Garmin?"
    static let disconnectMessage = "Os dados que já estão no app ficam. O sync com o Garmin para até você conectar de novo."
    static let connected = "Conectado"
    static let codeSentFormat = "O Garmin mandou um código por %@."
    static let methodNames = ["email": "e-mail", "sms": "SMS"]
    static let invalidCredentials = "E-mail ou senha incorretos."
    static let invalidCode = "Código incorreto. Confira e tente de novo."
    static let rateLimited = "O Garmin bloqueou tentativas seguidas. Espere alguns minutos e tente de novo."
    static let failed = "Não conectou. O Garmin pode ter mudado o login; tente de novo mais tarde."
    static let statusConnected = "Conectado"
    static let statusDisconnected = "Desconectado"
    static let syncedTodayFormat = "Sincronizado às %@"
    static let syncedFormat = "Sincronizado em %@"
}
