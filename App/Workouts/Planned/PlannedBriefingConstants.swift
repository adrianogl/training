import Foundation

enum PlannedBriefingConstants {
    static let longMeters = 15_000.0
    static let longSeconds = 75.0 * 60
    static let tempoZone = 4
    static let tempoWords = ["limiar", "tempo", "ritmo", "progressiv"]
    static let ignoredTitleWords: Set<String> = ["seg", "ter", "qua", "qui", "sex", "sáb", "sab", "dom"]
    static let similarLimit = 3
    static let fadeSignificant = 6.0
    static let entrySlowerSeconds = 10.0
    static let entryMeters = 2_000.0
    static let closingShare = 0.2
    static let heartMargin = 5.0
    static let readinessGood = 70
    static let readinessLow = 50
    static let reducedLongShare = 0.7
    static let reducedEasyPaceExtra = 30.0
    static let reducedRepsShare = 2.0 / 3
    static let hydrationMinutes = 60.0
    static let gelMinutes = 75.0
    static let gelEveryMinutes = 40.0
    static let hotTemperature = 24.0
    static let plannedHour = 7
    static let morningHours = 5...10
    static let bestHoursCount = 2
    static let heatSlowdown = "5 a 10 s/km"
    static let hardAerobicEffect = 3.5
    static let hardAnaerobicEffect = 2.0
    static let recoveryHours: [(effect: Double, hours: String)] = [(2, "12–24 h"), (3, "24 h"), (3.5, "24–36 h"), (4, "36–48 h"), (4.5, "48–60 h"), (5, "60–72 h")]
    static let watchTipLength = 40

    static let statDistance = "distância"
    static let statPace = "pace alvo"
    static let statTime = "tempo esperado"
    static let statLoad = "carga estimada"
    static let freePace = "livre"

    static let summaryLong = "Longão no pace alvo do começo ao fim, sem acelerar nos últimos quilômetros."
    static let summaryLongestFormat = " É o mais longo do bloco até agora: %@ km."
    static let summaryIntervalsFormat = "Intervalado de %d × %@. Mire %@/km nos tiros e trote leve nas recuperações."
    static let summaryTempoFormat = "Treino contínuo forte: segure %@/km sem passar do limite rápido da faixa."
    static let summaryEasy = "Rodagem leve: volume com pouco desgaste. Fique no pace alvo mesmo se sentir que dá para mais."
    static let summaryReadyFormat = " Pela sua prontidão de hoje (%d), dá para fazer completo."
    static let summaryCarefulFormat = " Prontidão %d: faça o planejado, sem forçar além do alvo."
    static let summaryLowFormat = " Prontidão %d: considere a versão reduzida em \"Se o dia não estiver bom\"."
    static let tagReadinessFormat = "Prontidão %d"
    static let tagRaceFormat = "%@ em %d dias"
    static let tagHeatFormat = "%d °C às %dh"

    static let phaseEntryWhen = "km 0–2"
    static let phaseEntryTitle = "Entrar no ritmo devagar"
    static let phaseEntryFormat = "Comece perto de %@/km e chegue em %@/km depois do segundo km."
    static let phaseEntryHeartFormat = " A FC deve ficar abaixo de %d bpm."
    static let phaseBlockWhenFormat = "km 2–%d"
    static let phaseBlockTitleFormat = "Bloco entre %@ e %@/km"
    static let phaseBlockFormat = "Mire %@/km, o meio da faixa."
    static let phaseBlockHeartFormat = " Se a FC passar de %d bpm, segure o ritmo mesmo que o pace caia para %@."
    static let phaseCloseWhenFormat = "km %d–%d"
    static let phaseCloseTitle = "Fechar no mesmo ritmo"
    static let phaseClose = "É aqui que o ritmo costuma cair. Se sobrar força, mantenha; não acelere."
    static let phaseCloseHeartFormat = " Se a FC passar de %d bpm, encerre no km %d."
    static let lengthMinutesFormat = "~%d min"

    static let repsEarly = "entre no ritmo, sem passar do limite rápido"
    static let repsMiddle = "o miolo da série; trote bem leve entre os tiros"
    static let repsLate = "só acelere se a FC do trote baixou bem"
    static let repsNote = "Os paces saem da faixa prescrita. A FC ao terminar vem dos seus últimos treinos parecidos."
    static let repsLabelSingle = "%dº"
    static let repsLabelRange = "%dº a %dº"
    static let repsLabelPair = "%dº e %dº"
    static let repsHeartFormat = "até %d"

    static let expectHeart = "FC média esperada (bpm)"
    static let expectEffect = "Training Effect aeróbico"
    static let expectRecovery = "recuperação estimada"
    static let expectNoteLong = "É normal a FC subir 5 a 8 bpm da metade em diante no mesmo pace. Acima disso, é sinal de calor ou cansaço."
    static let expectNoteIntervals = "A FC chega no alto da Z4 do meio para o fim de cada tiro e precisa baixar no trote antes do próximo."
    static let expectNoteDefault = "Os valores vêm dos seus treinos parecidos mais recentes."

    static let attentionHeatTitle = "Calor e umidade"
    static let attentionHeatFormat = "%d °C às %dh. Saia mais cedo ou aceite %@ mais lento com a mesma FC."
    static let attentionFadeTitle = "Queda de ritmo no fim"
    static let attentionFadeFormat = "O ritmo caiu %d s/km no fim do último treino parecido. Segure o começo."
    static let attentionWeekTitle = "Carga da semana"
    static let attentionWeekFormat = "Com este treino, a semana fecha em %@ km para %@ km de meta."
    static let attentionWeekNoGoalFormat = "Com este treino, a semana fecha em %@ km."
    static let attentionRecoveryTitle = "Recuperação desde o último treino forte"
    static let attentionRecoveryGoodFormat = "%d dias desde o último treino forte: recuperado."
    static let attentionRecoveryShortFormat = "Só %d dia(s) desde o último treino forte. Se as pernas estiverem pesadas, reduza."
    static let attentionReadinessTitle = "Prontidão baixa"
    static let attentionReadinessFormat = "Prontidão %d. Veja a versão reduzida abaixo."

    static let planBLowTitleFormat = "Prontidão abaixo de %d ou noite ruim"
    static let planBLongFormat = "Faça %@ km em Z2, a %@/km."
    static let planBIntervalsFormat = "Faça %d tiros em vez de %d, no mesmo alvo."
    static let planBDefault = "Faça o treino em Z2, sem os blocos fortes."
    static let planBPainTitle = "Dor ou FC alta já no aquecimento"
    static let planBPain = "Troque por 40 min leves e avise o treinador."

    static let previousNoteFadeFormat = "No treino parecido de %@, o ritmo caiu %d s/km no fim."
    static let previousNoteSteady = "Nos treinos parecidos, o ritmo ficou estável até o fim."

    static let carryHydration = "Água ou isotônico: ~500 ml por hora"
    static let carryGelFormat = "1 gel a cada 40 min (%d no total)"
    static let carryWatch = "Treino carregado no relógio"
    static let carryShoes = "Tênis de longão"

    static let raceLongDoneFormat = "Com este longão, o item Longão mais longo do checklist de %@ fica cumprido (%@ de %@ km)."
    static let raceLongProgressFormat = "Este longão aproxima o item Longão mais longo de %@: alvo de %@ km."

    static let bestHoursFormat = "Saindo às %dh você pega %d °C. Às %dh, conte com %@ a mais na mesma FC."
    static let bestHoursCool = "Manhã fresca: qualquer horário até as 10h funciona."

    static let compareDistance = "Distância"
    static let comparePace = "Pace"
    static let compareHeart = "FC média"
    static let compareFade = "Fim do treino"
    static let compareSteady = "sem cair"
    static let compareFadeFormat = "+%d s/km"
    static let compareDoneNote = "Cumpriu o plano."
    static let comparePartialNote = "Parte do plano ficou fora do alvo."

    static let watchHeatFormat = "%d° às %dh · saia cedo"
    static let watchHeartFormat = "FC até %d · %@"
    static let watchPaceFormat = "Mire %@/km"
    static let watchGel = "gel no km %d"
}

enum PlannedBriefingLoaderConstants {
    static let similarLimit = 3
    static let longShare = 0.8
    static let longMinimumMeters = 14_000.0
    static let fadeMinimumMeters = 5_000.0
    static let fadeMiddleStart = 0.2
    static let fadeMiddleEnd = 0.8
    static let runningMinimumSpeed = 2.2
    static let fadeMinimumSamples = 5
    static let blockDays = 84
}
