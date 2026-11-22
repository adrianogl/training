import Foundation

extension TrainerEngineText {

    static func racePaceLongTitle(meters: Double, block: TrainerQualityBlock, race: String) -> String {
        title(kind: .long, meters: meters)
    }

    static func raceLabel(_ meters: Double?) -> String {
        switch meters ?? 0 {
        case 20_000..<23_000: "da meia"
        case 40_000..<45_000: "da maratona"
        default: "da prova"
        }
    }

    static func vo2FormatReason(_ format: TrainerVo2Format) -> String {
        switch format {
        case .hills: "Subidas na fase base: força e mecânica de corrida com menos impacto que o tiro no plano. A volta é trotando na descida."
        case .oneKm: "Tiros de 1 km: o formato base do pace I."
        case .eightHundred: "Tiros de 800 m: mais repetições no mesmo pace, com a recuperação mais curta."
        case .longReps: "Tiros de 1,5 km: mais tempo perto do VO2 em cada repetição."
        case .shortReps: "Tiros de 400 m: velocidade e economia, com pouco tempo em cada repetição."
        case .pyramid: "Pirâmide de 1,5 km para 1 km: segura o pace com a fadiga acumulada."
        }
    }

    static let hillsRule = "Tiros em subida, por esforço forte e não por pace."

    static func thresholdFormatReason(_ format: TrainerThresholdFormat, meters: Double) -> String {
        switch format {
        case .ladder: "Semana da escada de blocos; na próxima o limiar muda de formato."
        case .continuous: "Tempo contínuo de \(kilometers(meters)): segura o limiar sem pausa, intercalado com a escada de blocos."
        case .progressive: "Cada bloco sai 5 s/km mais rápido que o anterior, para aprender a acelerar cansado."
        }
    }

    static func progressiveThresholdRule(_ blocks: [TrainerQualityBlock], rest: Double) -> String {
        "Limiar progressivo \(sessionLabel(blocks)), \(restClock(rest)) parado entre os blocos."
    }

    static func longestReason(share: Double, note: String?) -> String {
        (["Maior longão do bloco, todo leve: até \(Int((share * 100).rounded()))% da semana e 150 min."] + noteSentence(note))
            .joined(separator: " ")
    }

    static func noteSentence(_ note: String?) -> [String] {
        note.map { ["\($0.prefix(1).uppercased() + $0.dropFirst())."] } ?? []
    }

    static let stimulusShorter = "Fica mais curto que o maior longão do bloco porque tem trecho forte."

    static func progressiveLongReason(meters: Double, from: Double, to: Double) -> String {
        "Últimos \(kilometers(meters)) progressivos, de \(pace(from))/km até \(pace(to))/km: treina acelerar no fim com cansaço. \(stimulusShorter)"
    }

    static func fastFinishReason(meters: Double, pace: Double) -> String {
        "Últimos \(kilometers(meters)) a \(self.pace(pace))/km: fecha forte com as pernas cansadas. \(stimulusShorter)"
    }

    static func racePaceLongReason(block: TrainerQualityBlock, pace: Double, race: String, jog: Double) -> String {
        "\(block.repeats) × \(distance(block.meters)) no ritmo \(race) (\(self.pace(pace))/km) com \(distance(jog)) leve entre os blocos: ensaio do ritmo com cansaço. \(stimulusShorter)"
    }

    static func stridesReason(rest: Double) -> String {
        "No fim, 6 × 100 m de aceleração com \(restClock(rest)) parado entre elas: solta a passada sem custo de recuperação."
    }

    static func mediumLongReason(meters: Double, week: Double) -> String {
        "Média-longa de \(kilometers(meters)) no meio da semana: com \(kilometers(week)) na semana, uma corrida mais longa entre o limiar e o VO2 divide o volume com o longão. O km sai das outras rodagens; até 75 min."
    }

    static func fartlekNote(_ meters: Double) -> String {
        "só se a prontidão ≥ 60; senão rodagem leve de \(kilometers(meters))"
    }

    static func fartlekReason(warmup: Double, meters: Double) -> String {
        "Fartlek de \(kilometers(meters)): \(kilometers(warmup)) leves e 6 × 500 m forte com 500 m leve entre eles. Entra uma semana sim, outra não, para mexer no ritmo sem virar outro treino de qualidade. Só se a prontidão da manhã estiver em 60 ou mais; senão, rodagem leve na mesma distância."
    }

    static func fartlekSkipped(_ score: Int, meters: Double) -> String {
        "Prontidão \(score) hoje: rodagem leve de \(kilometers(meters)) no lugar do fartlek."
    }
}
