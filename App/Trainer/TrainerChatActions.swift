import Foundation
import Insights
import TrainingCore

enum TrainerChatActions {
    private typealias C = TrainerChatConstants

    static func detect(question: String, answer: String, plan: TrainerPlan, today: Day) -> [TrainerChatAction] {
        var actions: [TrainerChatAction] = []
        if let swap = swap(in: normalized(question), plan: plan, today: today) { actions.append(.swap(swap)) }
        if let request = request(question: question, answer: answer) { actions.append(.request(request)) }
        return actions
    }

    static func label(for swap: TrainerChatSwap) -> String {
        String(format: C.swapLabelFormat, TrainerConstants.weekdayFull[TrainerText.weekday(swap.first)], TrainerConstants.weekdayFull[TrainerText.weekday(swap.second)])
    }

    private static func swap(in text: String, plan: TrainerPlan, today: Day) -> TrainerChatSwap? {
        guard text.range(of: C.swapVerbPattern, options: .regularExpression) != nil else { return nil }
        let mentioned = text.matches(of: /(segunda|terca|quarta|quinta|sexta|sabado|domingo)/).compactMap { match in
            C.weekdayStems.firstIndex(of: String(match.output.1))
        }
        guard mentioned.count >= 2, mentioned[0] != mentioned[1] else { return nil }
        let days = mentioned.prefix(2).map { index -> Day in
            let day = today.weekStart.adding(days: index)
            return day < today ? day.adding(days: TrainerConstants.weekdayCount) : day
        }
        let workouts = days.compactMap { day in plan.workouts.first { $0.day == day } }
        guard workouts.count == 2, days[0].weekStart == days[1].weekStart, workouts.allSatisfy({ $0.kind != .race }) else { return nil }
        return TrainerChatSwap(first: days[0], second: days[1])
    }

    private static func request(question: String, answer: String) -> TrainerRequestPrefill? {
        let text = normalized(question + " " + answer)
        guard let match = C.requestPatterns.first(where: { text.range(of: $0.pattern, options: .regularExpression) != nil }) else { return nil }
        return TrainerRequestPrefill(category: match.category, text: question.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func normalized(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: TrainerConstants.locale)
    }
}
