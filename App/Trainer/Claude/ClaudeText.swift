import Foundation
import Insights

enum ClaudeText {
    static let source = "Claude"
    static let askButton = "Pedir ao Claude"
    static let pasteButton = "Colar treinos do Claude"
    static let requestTitle = "Pedir ao Claude"
    static let periodLabel = "Período"
    static let extraLabel = "Pedido extra (opcional)"
    static let extraPlaceholder = "Ex.: quero mais glúteo médio, joelho chato depois do longão"
    static let copy = "Copiar pacote para o Claude"
    static let copied = "Copiado. Cole numa conversa com o Claude e, quando ele responder, copie o JSON e toque em \"Colar treinos do Claude\"."
    static let includesTitle = "O pacote leva"
    static let includes = [
        "Seus dias de força do treinador, com foco, duração e local",
        "Dias do MFIT, com o que o professor trabalhou",
        "Corrida do período (plano ou Garmin)",
        "Prontidão dos últimos 7 dias e dor marcada",
        "Últimas cargas e o catálogo de exercícios do Garmin",
        "Regras de força e o formato da resposta",
    ]
    static let importTitle = "Treinos do Claude"
    static let applyFormat = "Aplicar %d dia(s)"
    static let copyErrors = "Copiar erros para o Claude"
    static let errorsCopied = "Erros copiados. Cole na conversa com o Claude para ele corrigir."
    static let applied = "Aplicado."
    static let invalidJSON = "Não achei um JSON válido na área de transferência. Copie só a resposta do Claude e tente de novo."
    static let unsupportedFormat = "Versão do formato que o app não conhece (%d). Peça ao Claude para usar \"versao\": 1."
    static let backToGenerator = "Voltar ao gerador neste dia"
    static let whyTitle = "Por que, segundo o Claude"
    static let close = "Fechar"
    static let estimatedFormat = "%d exercícios · %d min estimados"
    static let mcpGenerateFailed = "Não deu para gerar o token. Confira a conexão e tente de novo."
    static let mcpRevokeFailed = "Não deu para revogar o token. Confira a conexão e tente de novo."
    static let settingsTitle = "Claude"
    static let settingsIntro = "Deixa o Claude Desktop ou o Claude Code montarem seus treinos de força direto no trAIning. Você revisa e aplica no app."
    static let generateToken = "Gerar token"
    static let regenerateToken = "Gerar outro token"
    static let revokeToken = "Revogar"
    static let codeTitle = "Claude Code"
    static let desktopTitle = "Claude Desktop"
    static let copyCommand = "Copiar comando"
    static let copyConfig = "Copiar configuração"
    static let copiedShort = "Copiado."
    static let tokenOnce = "O token aparece só agora. Se perder, gere outro."
    static let activeSinceFormat = "Token ativo desde %@."
    static let noToken = "Nenhum token ativo."
    static let needsSync = "Ative a sincronização com o servidor em Ajustes para usar o Claude."
    static let inboxTitle = "O Claude enviou treinos"
    static let inboxCountFormat = "%d dia(s) · %d válido(s) · %d recusado(s)"
    static let review = "Revisar e aplicar"
    static let replacesNote = "Troca o treino do MFIT só neste dia e tira o do professor do Garmin."
    static let discard = "Descartar"

    static func codeCommand(token: String) -> String {
        "claude mcp add --transport http training \(ClaudeConstants.mcpURL) --header \"Authorization: Bearer \(token)\""
    }

    static func desktopConfig(token: String) -> String {
        """
        "training": {
          "command": "npx",
          "args": ["-y", "mcp-remote", "\(ClaudeConstants.mcpURL)", "--header", "Authorization: Bearer \(token)"]
        }
        """
    }

    static let errorsIntro = "O app recusou estes pontos. Corrija e devolva o JSON completo de novo, no mesmo formato:"

    static func periodName(_ period: ClaudeRequestPeriod, race: String?) -> String {
        switch period {
        case .nextWeek: "Próxima semana"
        case .untilRace: race.map { "Até a prova (\($0))" } ?? "Próximas 12 semanas"
        }
    }

    static func issue(_ issue: ClaudeIssue) -> String {
        switch issue {
        case .invalidDate: "data inválida"
        case .pastDay: "dia que já passou"
        case .outOfPeriod: "fora do período pedido"
        case .mfitDay: "dia do MFIT, não será aplicado"
        case .notTrainerDay: "não é um dia de força do treinador"
        case .unknownExercise(let id): "\"\(id)\" não existe no catálogo"
        case .wrongPlace(let id): "\"\(id)\" não cabe no local do dia"
        case .painRegion(let id): "\"\(id)\" carrega uma região com dor marcada"
        case .doseOutOfRange(let id): "\"\(id)\" com séries, repetições, segundos ou descanso fora da faixa"
        case .noExercises: "sem exercícios"
        case .tooManyExercises: "mais de 12 exercícios"
        case .heavyLegsBeforeQuality: "perna pesada nas 48 h antes de limiar, VO2 ou longão"
        case .nearRace: "força nos 3 dias antes da prova"
        case .durationOff(let estimated, let planned): "\(estimated) min estimados para \(planned) marcados"
        case .loadJump(let id): "carga de \"\(id)\" mais de 5% acima da última"
        case .replacesMFIT: "substitui o treino do MFIT neste dia"
        }
    }

    static let instructions = """
    Você é o treinador de força de um corredor. Monte os treinos de força dos dias listados em "dias_do_treinador" dentro do período, usando o contexto abaixo.
    - Use só exercícios do "catalogo", pelo "id" (categoria/exercício do catálogo oficial da Garmin). Cada linha segue "catalogo_formato". Respeite o "local" de cada dia (academia, casa ou só peso do corpo): equipamentos kettlebell, medicineBall, suspension e swissBall só na academia.
    - Os dias do MFIT são do professor: complemente o que ele já trabalha. Se precisar trocar o treino do professor num dia (por exemplo, perto da prova), monte o treino desse dia com \"substitui_mfit\": true; o app troca o treino do professor só naquela data e tira o dele do Garmin.
    - Siga as "regras". Periodize ao longo do período: progressão de carga e volume, semanas mais leves e redução perto da prova.
    - A corrida só é conhecida para as primeiras semanas; nas outras, mantenha o padrão da semana conhecida.
    - Responda apenas com o JSON no formato de "formato_da_resposta", sem texto antes ou depois. Em "porque", explique em uma frase a escolha do dia.
    """

    static let catalogFormat = "id|padrao|equipamento|regioes que carrega|focos|marcas (u = unilateral, i = isometria, em segundos)"

    static let rules = [
        "Perna pesada (2 ou mais exercícios de agachamento, terra, unilateral ou pliometria com carga) nunca nas 48 h antes de limiar, VO2 ou longão.",
        "Em dia de limiar, VO2 ou longão, só mobilidade e core, ou superiores.",
        "Nos 3 dias antes da prova, sem força; de 4 a 7 dias antes, só mobilidade curta.",
        "Nenhum exercício que carregue uma região com dor marcada.",
        "Séries de 1 a 6, repetições de 1 a 30, isometria de 10 a 120 s, descanso de 0 a 240 s, no máximo 12 exercícios.",
        "Carga em kg só quando houver base nas últimas cargas; subir no máximo 5% por vez.",
        "Duração estimada até 10 min diferente dos minutos do dia.",
        "Priorize exercícios de corredor: unilateral, panturrilha e sóleo, glúteo médio, anti-rotação, mobilidade de quadril e tornozelo.",
    ]

    static let responseFormat = """
    {
      "versao": 1,
      "autor": "claude",
      "resumo": "uma frase sobre o período",
      "treinos": [
        {
          "dia": "AAAA-MM-DD",
          "foco": "upper | lower | fullBody | core",
          "minutos": 25,
          "local": "gym | home | bodyweight",
          "porque": "uma frase",
          "substitui_mfit": false,
          "exercicios": [
            { "id": "id do catálogo", "series": 3, "reps": 10, "descanso": 30 },
            { "id": "id do catálogo", "series": 3, "segundos": 30, "descanso": 30 },
            { "id": "id do catálogo", "series": 4, "reps": 6, "descanso": 150, "kg": 60 }
          ]
        }
      ]
    }
    """
}
