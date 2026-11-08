import Foundation

enum CLIConstants {
    static let keyRelativePath = ".config/garmin/connect-personal-api-key"
    static let missing = "—"
    static let usageExitCode: Int32 = 64
    static let failureExitCode: Int32 = 1
    static let usage = """
        uso: trainingctl <sync|report|reprocess> --store <caminho> [--limit N]
          sync       baixa os dados do Garmin para o store SQLite
          report     imprime as métricas calculadas a partir do store
          reprocess  baixa de novo os FIT lidos por versão antiga do leitor (--limit só aqui)
        """
}
