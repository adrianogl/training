enum ConnectionNotifierText {
    static func title(_ source: ConnectionSource) -> String {
        switch source {
        case .garmin: "Garmin desconectado"
        case .strava: "Strava desconectado"
        }
    }

    static func body(_ source: ConnectionSource) -> String {
        switch source {
        case .garmin: "O Garmin recusou o acesso. Conecte de novo em Ajustes para voltar a sincronizar."
        case .strava: "Entre de novo em Ajustes para continuar enviando as análises ao Strava."
        }
    }
}
