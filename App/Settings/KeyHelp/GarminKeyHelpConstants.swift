import SwiftUI

enum GarminKeyHelpConstants {
    static let title = "Chave do Garmin"
    static let done = "OK"
    static let openLink = "Como gerar a chave?"
    static let intro = "É uma chave pessoal que o Garmin Connect gera para você. Com ela o Training baixa seus treinos, sono, HRV e prontidão. A chave só lê: não muda nada na sua conta e não usa sua senha."
    static let openButton = "Abrir no Garmin Connect"
    static let caption = "Desenhos com os nomes que o Garmin Connect usa hoje."
    static let facts = [
        "Fica guardada só no Keychain deste aparelho. No iPad, cole a mesma chave de novo.",
        "Quando vencer, a conexão falha e o app pede uma chave nova.",
        "Para cortar o acesso, apague a chave no Garmin Connect.",
    ]
    static let steps = [
        GarminKeyHelpStep(number: 1, title: "Abra a página da chave", detail: "O botão abaixo abre o Garmin Connect em Configurações › Chave de API pessoal. Entre com a sua conta, se ele pedir, e toque em Criar chave.", illustration: .openPage),
        GarminKeyHelpStep(number: 2, title: "Escolha a validade e toque em Criar", detail: "Em \"A chave expira em\", troque os 30 dias pelo prazo mais longo. Assim você troca menos vezes.", illustration: .chooseExpiry),
        GarminKeyHelpStep(number: 3, title: "Aceite os termos", detail: "O Garmin mostra os Termos Complementares da API pessoal. Toque em Aceitar.", illustration: .acceptTerms),
        GarminKeyHelpStep(number: 4, title: "Copie a chave", detail: "Copie assim que ela aparecer na tela.", illustration: .copyKey),
        GarminKeyHelpStep(number: 5, title: "Cole aqui e salve", detail: "Volte para Ajustes, cole no campo, toque em Salvar chave e depois em Testar conexão.", illustration: .pasteInApp),
    ]

    static let host = "connect.garmin.com"
    static let settingsTitle = "Configurações"
    static let pageTitle = "Chave de API pessoal"
    static let createKey = "Criar chave"
    static let createTitle = "Criar chave de API pessoal"
    static let expiryLabel = "A chave expira em"
    static let expiryValue = "1 ano"
    static let create = "Criar"
    static let termsTitle = "Termos Complementares"
    static let reject = "Rejeitar"
    static let accept = "Aceitar"
    static let maskedKey = "a7Kq••••••••••••••Zt2"
    static let copy = "Copiar"
    static let pastedKey = "••••••••••••••••••••"
    static let saveKey = "Salvar chave"
    static let testConnection = "Testar conexão"

    static let pageBlue = Color(red: 0.18, green: 0.44, blue: 0.84)
    static let paper = Color.white.opacity(0.06)
    static let field = Color.white.opacity(0.10)
    static let illustrationRadius: CGFloat = 10
    static let numberSize: CGFloat = 26
    static let tapSize: CGFloat = 14
}
