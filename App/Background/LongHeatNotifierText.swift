enum LongHeatNotifierText {
    static let title = "Calor no longão de amanhã"

    static func body(_ day: TrainerHeatDay) -> String? {
        guard let usual = day.hour(day.usualHour) else { return nil }
        let conditions = usual.dewPoint.map { "\(TrainerText.temperature(usual.temperature)) com orvalho de \(TrainerText.temperature($0))" }
            ?? TrainerText.temperature(usual.temperature)
        var text = "No seu horário, \(usual.hour)h, \(conditions): o pace sobe \(usual.heat.paceOffset) s/km."
        if let suggested = day.suggestedHour.flatMap(day.hour) {
            text += suggested.heat.isHot
                ? " Saindo às \(suggested.hour)h, só \(suggested.heat.paceOffset) s/km."
                : " Saindo às \(suggested.hour)h, sem ajuste."
        }
        return text
    }
}
