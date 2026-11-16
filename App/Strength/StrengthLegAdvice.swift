import GarminAPI
import SwiftUI
import Insights

enum StrengthLegAdvice {
    static func text(_ today: TodayWorkoutSource?, leg: StrengthLegDay?) -> String? {
        guard let leg, let today else { return nil }
        switch today {
        case .garmin(let plan):
            let slow = PlannedBriefingBuilder.paceTarget(plan)?.slow
            switch PlannedBriefingBuilder.kind(plan) {
            case .intervals: return StrengthText.legIntervalsAdvice(leg, slowPace: slow, reps: plan.steps.first { $0.repeats > 1 }?.repeats)
            case .tempo: return StrengthText.legTempoAdvice(leg, slowPace: slow)
            case .long: return StrengthText.legLongAdvice(leg)
            case .easy: return nil
            }
        case .trainer(let row):
            switch row.workout.kind {
            case .vo2max: return StrengthText.legIntervalsAdvice(leg, slowPace: nil, reps: nil)
            case .threshold: return StrengthText.legTempoAdvice(leg, slowPace: nil)
            case .long: return StrengthText.legLongAdvice(leg)
            default: return nil
            }
        }
    }
}

struct StrengthLegFactorRow: View {
    let leg: StrengthLegDay

    var body: some View {
        HStack(spacing: 10) {
            Text("F")
                .font(.footnote.weight(.heavy))
                .foregroundStyle(BrandColors.strength)
                .frame(width: 28, height: 28)
                .background(BrandColors.strength.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(StrengthText.legFactorTitle).font(.footnote.weight(.semibold)).foregroundStyle(BrandColors.text)
                Text(StrengthText.legFactorDetail(leg)).font(.caption).foregroundStyle(BrandColors.dim)
            }
            Spacer(minLength: 0)
        }
        .padding(9)
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(BrandColors.line))
    }
}
