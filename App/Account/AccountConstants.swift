import Foundation
import os

enum AccountConstants {
    static let logger = Logger(subsystem: "trAIning", category: "Account")
    static let keychainAccount = "account-session"
    static let userDefaultsKey = "accountUser"
    static let passwordMinLength = 10
    static let fieldHeight: Double = 50
    static let buttonHeight: Double = 52
    static let cornerRadius: Double = 14
    static let formMaxWidth: Double = 420

    static let loginTitle = "Entrar"
    static let loginSubtitle = "Use o mesmo e-mail e senha do site."
    static let signupTitle = "Criar conta"
    static let signupSubtitle = "A mesma conta vale no app e no site."
    static let legacyNote = "Suas provas sincronizadas entram na conta nova."
    static let forgotTitle = "Recuperar senha"
    static let forgotSubtitle = "Enviamos um link para o e-mail da conta. Ele vale por 30 minutos."
    static let forgotSentTitle = "Confira seu e-mail"
    static let forgotSentText = "Se o e-mail tiver conta confirmada, o link chega em instantes. Olhe também o spam."
    static let nameLabel = "Nome"
    static let emailLabel = "E-mail"
    static let passwordLabel = "Senha"
    static let confirmLabel = "Confirmar senha"
    static let currentPasswordLabel = "Senha atual"
    static let newPasswordLabel = "Nova senha"
    static let confirmNewLabel = "Confirmar nova senha"
    static let passwordHint = "Mínimo de 10 caracteres."
    static let newPasswordHint = "Mínimo de 10 caracteres, diferente da atual."
    static let enter = "Entrar"
    static let create = "Criar conta"
    static let sendLink = "Enviar link"
    static let forgotLink = "Esqueci a senha"
    static let noAccount = "Ainda não tem conta?"
    static let haveAccount = "Já tem conta?"
    static let backToLogin = "Voltar para o login"
    static let accountTitle = "Conta"
    static let changePasswordTitle = "Alterar senha"
    static let endOthers = "Encerrar outras sessões"
    static let savePassword = "Salvar nova senha"
    static let passwordChanged = "Senha alterada."
    static let sessionsTitle = "Sessões ativas"
    static let thisDevice = "Este aparelho"
    static let endSession = "Encerrar"
    static let signOut = "Sair"
    static let deleteAccount = "Apagar conta"
    static let deleteConfirmTitle = "Apagar a conta?"
    static let deleteConfirmText = "Remove do servidor as provas, o token do relógio e a conta. Os treinos neste aparelho ficam até você apagar os dados locais. Não dá para desfazer."
    static let deleteNote = "Apagar a conta remove do servidor as provas, o token do relógio e a conta. Não dá para desfazer."
    static let unverified = "E-mail não confirmado."
    static let resend = "Reenviar confirmação"
    static let resent = "Enviamos o link de novo."
    static let cancel = "Cancelar"

    static let mismatch = "As senhas não são iguais."
    static let shortPassword = "A senha precisa de pelo menos 10 caracteres."
    static let invalidCredentials = "E-mail ou senha incorretos."
    static let emailTaken = "Já existe uma conta com esse e-mail. Entre com ela."
    static let legacyUnavailable = "A chave de sync deste aparelho já está numa conta. Entre com o e-mail dela."
    static let invalidEmail = "Confira o e-mail."
    static let invalidName = "Informe seu nome."
    static let rateLimited = "Muitas tentativas. Espere alguns minutos."
    static let mailUnavailable = "O envio de e-mail não está disponível agora."
    static let wrongCurrent = "A senha atual não confere."
    static let offline = "Não conectou ao servidor. Confira a internet."
    static let generic = "Não deu certo. Tente de novo."
}
