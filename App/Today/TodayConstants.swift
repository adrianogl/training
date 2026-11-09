import Foundation
import Metrics

enum TodayConstants {
    static let moderateThreshold = 40
    static let hardThreshold = 70
    static let fitnessHistoryDays = 60
    static let predictionHistoryDays = 120
    static let gridMinimumWidth: Double = 360
    static let factorBarFullScale = 10.0
    static let chartHeight: Double = 90
    static let predictionChartHeight: Double = 120
    static let weekBarHeight: Double = 60
    static let weekBarMinimum: Double = 3
    static let weekdayLetters = ["S", "T", "Q", "Q", "S", "S", "D"]
    static let months = [
        "janeiro", "fevereiro", "março", "abril", "maio", "junho",
        "julho", "agosto", "setembro", "outubro", "novembro", "dezembro",
    ]
    static let earlyMonthLimit = 10
    static let midMonthLimit = 20
    static let daysPerWeek = 7.0
    static let predictionLabels = ["5 km", "10 km", "21,1 km", "42,2 km"]
    static let minusSign = "\u{2212}"
    static let ratioFormat = "%.2f"

    static let todayTitle = "Hoje"
    static let readinessTitle = "Prontidão"
    static let readinessEmpty = "Sem dados de recuperação de hoje."
    static let verdictPhrases: [ReadinessVerdict: String] = [
        .hard: "Pode treinar forte",
        .moderate: "Treino moderado",
        .rest: "Dia de descanso",
    ]
    static let supportHRV = "HRV"
    static let supportSleep = "Sono"
    static let supportLoad = "A:C"
    static let supportStress = "Stress"
    static let rulerRest = "descanso"
    static let rulerModerate = "moderado"
    static let rulerHard = "forte"

    static let fitnessTitleWithRace = "Fitness · até a prova"
    static let fitnessTitleWithoutRace = "Fitness"
    static let fitnessNow = "hoje"
    static let fitnessPeak = "pico"
    static let fitnessRaceForm = "forma no dia"
    static let fitnessLegend = "azul: fitness · amarelo: forma · tracejado: projeção"
    static let fitnessEmpty = "Ainda sem treinos com carga para calcular o fitness."

    static let predictionTitle = "Previsão"
    static let predictionToday = "Hoje"
    static let predictionRaceDay = "No dia da prova"
    static let predictionEmpty = "Ainda sem esforços suficientes para prever."
    static let predictionBandPrefix = "faixa"
    static let predictionYearAgoPrefix = "há 12 meses"
    static let goalPrefix = "meta"
    static let goalOn = "Meta de %@ deve chegar em %@ de %@%@."
    static let goalAfterRace = ", %d %@ depois da prova"
    static let goalBeaten = "A previsão já está abaixo da meta."
    static let goalUnreachable = "Na tendência atual, a meta não é alcançada."

    static let weekTitle = "Semana"
    static let weekFooter = "semana passada %@ km · média 4 semanas %@ km"
    static let predictionsTitle = "Previsões"
    static let lastRunTitle = "Último treino"

    static let detailTitle = "Prontidão"
    static let detailUp = "Puxando para cima"
    static let detailDown = "Puxando para baixo"
    static let detailNoBaseline = "Valor do dia"
    static let detailMissing = "Sem dado"
    static let detailMissingValue = "sem dado"
    static let detailStressContext = "Stress do dia aparece como contexto, mas não entra na nota."
    static let detailExplanationTitle = "Como os pontos são calculados"
    static let detailExplanation = "A prontidão é a média ponderada de quatro notas de 0 a 100: HRV (35%), sono (25%), Body Battery (20%) e carga aguda:crônica (20%). Cada fator mostra quanto empurra a nota de hoje em relação ao seu normal dos últimos 30 dias: peso × (nota do fator hoje − média de 30 dias da nota do fator). O veredito vem dos limites fixos de 40 e 70. O normal só vale a partir de 14 dias com dado nos últimos 30."
    static let detailNoNormal = "Ainda sem normal de 30 dias para comparar."
    static let loadIdealRange = "ideal 0,8–1,3"

    static let componentNames: [ReadinessComponent: String] = [
        .hrv: "HRV da noite",
        .sleep: "Sono",
        .bodyBattery: "Body Battery ao acordar",
        .load: "Carga da semana",
    ]

    static let comingSoon = "Em breve"
    static let sidebarRaceTitle = "Prova-alvo"
}
