enum RaceLessonConstants {
    static let sameTimeSeconds = 5.0
    static let fullSplitRatio = 0.99
    static let minimumSplits = 2
    static let openingKm = 5
    static let minimumEasing = 3.0
    static let strongFinishSeconds = 5.0

    static let versus = "vs."
    static let km = "km"
    static let eve = "véspera"
    static let goal = "meta"
    static let median = "mediana do resto da prova"

    static let aboveGoal = "%@ acima da meta"
    static let belowGoal = "%@ abaixo da meta"
    static let beatEve = "%@ melhor que a previsão da véspera"
    static let paceDropped = "Ritmo caiu %d s/km na segunda metade"
    static let negativeSplit = "Segunda metade %d s/km mais rápida"
    static let evenSplit = "Ritmo constante nas duas metades"
    static let strongFinish = "Último km a %@ (−%d s/km vs. o resto)"

    static let whyGoalAggressive = "A previsão da véspera era %@: a meta estava %@ mais agressiva que a forma do dia."
    static let whyGoalMissedOnDay = "A previsão da véspera não estava acima da meta, então o tempo se perdeu na execução do dia."
    static let whyGoalMissed = "Sem previsão da véspera não dá para separar meta agressiva de execução."
    static let whyBelowGoal = "A meta estava conservadora para a forma do dia."
    static let whyBeatEve = "Você rendeu acima do que a forma indicava na véspera."
    static let whyPaceDropped = "A primeira metade custou caro: o ritmo da largada ficou acima do que a forma sustentava até o fim."
    static let whyNegativeSplit = "Largada contida e força para o fim: a distribuição do esforço funcionou."
    static let whyEvenSplit = "O esforço ficou distribuído por igual, sem pagar no fim pela largada."
    static let whyStrongFinish = "Sobrou força para o final. Com a largada mais contida, esse ganho viria antes."

    static let nextStartSlower = "Largar %d s/km mais lento nos primeiros %d km"
    static let nextStartTarget = "alvo %@/km nos primeiros %d km"
    static let whyNextStartSlower = "Segurar a largada divide o esforço e evita a queda da segunda metade."
    static let nextUseEve = "Definir a meta pela previsão da véspera"
    static let whyNextUseEve = "A previsão já mostrava que a meta pedia mais do que a forma do dia entregava."
    static let nextRepeat = "Repetir a mesma estratégia"
    static let whyNextRepeat = "A execução saiu como planejada, sem queda de ritmo nem meta fora da forma."
}
