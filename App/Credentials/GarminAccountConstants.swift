import Foundation

enum GarminAccountConstants {
    static let sectionTitle = "Conta Garmin"
    static let footer = "Dá acesso aos treinos planejados e aos percursos que você cria no Garmin Connect. O app guarda só a sessão no Keychain, nunca a senha."
    static let emailPlaceholder = "E-mail da conta Garmin"
    static let passwordPlaceholder = "Senha"
    static let codePlaceholder = "Código de verificação"
    static let signIn = "Entrar"
    static let signingIn = "Entrando…"
    static let confirmCode = "Confirmar código"
    static let signOut = "Sair da conta"
    static let connected = "Conectada"
    static let codeSentFormat = "O Garmin mandou um código por %@."
    static let methodNames = ["email": "e-mail", "sms": "SMS"]
    static let invalidCredentials = "E-mail ou senha incorretos."
    static let invalidCode = "Código incorreto. Confira e tente de novo."
    static let rateLimited = "O Garmin bloqueou tentativas seguidas. Espere alguns minutos e tente de novo."
    static let failed = "Não conectou. O Garmin pode ter mudado o login; tente de novo mais tarde."
    static let statusSignedIn = "conta conectada"
    static let statusSignedOut = "sem conta"
}
