import ActivityKit
import SwiftUI
import WidgetKit

private typealias C = StrengthLiveWidgetConstants

struct StrengthLiveLockView: View {
    let title: String
    let state: StrengthLiveAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: C.rowSpacing) {
            StrengthLiveHeader(title: title, state: state)
            HStack(alignment: .bottom, spacing: 12) {
                StrengthLiveDetail(state: state)
                Spacer(minLength: 0)
                StrengthLiveBig(state: state)
            }
            StrengthLiveBar(state: state)
        }
        .padding(C.cardPadding)
        .foregroundStyle(C.text)
    }
}

struct StrengthLiveHeader: View {
    let title: String
    let state: StrengthLiveAttributes.ContentState

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Image(C.iconName).resizable().frame(width: C.iconSize, height: C.iconSize).clipShape(RoundedRectangle(cornerRadius: C.iconRadius))
                Text(title).font(.subheadline.bold())
            }
            Spacer()
            Text("\(state.setsDone)/\(state.setsTotal)").font(.subheadline.monospacedDigit().bold()).foregroundStyle(C.lilac)
            if let heartRate = state.heartRate {
                Label("\(heartRate)", systemImage: C.heartSymbol).font(.subheadline.monospacedDigit().bold()).foregroundStyle(C.heart)
            }
        }
    }
}

struct StrengthLiveDetail: View {
    let state: StrengthLiveAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(StrengthLiveText.label(state)).font(.caption.bold()).foregroundStyle(StrengthLiveText.color(state.moment))
            switch state.moment {
            case .resting:
                if let done = state.lastDone { prefixed(C.donePrefix, done) }
                if let target = state.target {
                    (Text(C.nextPrefix).foregroundStyle(C.dim) + Text(target).foregroundStyle(C.text) + Text(String(format: C.nextSuffix, state.setNumber)).foregroundStyle(C.dim))
                        .font(.footnote)
                }
            case .restOver:
                name
                if let ends = state.restEndsAt {
                    (Text(C.overPrefix).foregroundStyle(C.dim) + Text(C.plus).foregroundStyle(C.yellow) + Text(timerInterval: ends...Date.distantFuture, countsDown: false).foregroundStyle(C.yellow) + Text(C.overSuffix).foregroundStyle(C.dim))
                        .font(.footnote.monospacedDigit())
                }
            default:
                name
                if let last = state.last { prefixed(C.lastPrefix, last) }
            }
        }
        .lineLimit(1)
    }

    @ViewBuilder private var name: some View {
        if let exerciseName = state.exerciseName {
            Text(exerciseName).font(.callout.bold())
        }
    }

    private func prefixed(_ prefix: String, _ value: String) -> some View {
        (Text(prefix).foregroundStyle(C.dim) + Text(value).foregroundStyle(C.soft)).font(.footnote.monospacedDigit())
    }
}

struct StrengthLiveBig: View {
    let state: StrengthLiveAttributes.ContentState

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            if state.moment == .resting, let ends = state.restEndsAt {
                Text(timerInterval: Date.now...max(ends, .now), countsDown: true)
                    .font(.system(size: 40, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(C.blue)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 120, alignment: .trailing)
                if let seconds = state.restSeconds {
                    Text(C.restOfPrefix + StrengthLiveText.clock(seconds)).font(.caption2).foregroundStyle(C.dim)
                }
            } else if let target = state.target {
                Text(target)
                    .font(.system(size: 40, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(StrengthLiveText.color(state.moment))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if target.contains("×") {
                    Text(C.kilograms).font(.caption2).foregroundStyle(C.dim)
                }
            }
        }
    }
}

struct StrengthLiveBar: View {
    let state: StrengthLiveAttributes.ContentState

    var body: some View {
        if state.moment == .resting, let ends = state.restEndsAt, let seconds = state.restSeconds, seconds > 0 {
            ProgressView(timerInterval: ends.addingTimeInterval(-Double(seconds))...ends, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                .tint(C.blue)
        } else if state.setCount > 0 {
            HStack(spacing: C.barSpacing) {
                ForEach(0..<state.setCount, id: \.self) { index in
                    Capsule().fill(segment(index)).frame(height: C.barHeight)
                }
            }
        }
    }

    private func segment(_ index: Int) -> Color {
        if index < state.exerciseSetsDone { return C.lilac }
        guard index == state.exerciseSetsDone else { return Color.white.opacity(0.12) }
        return state.moment == .restOver ? C.lime.opacity(0.55) : C.lilac.opacity(0.40)
    }
}

enum StrengthLiveText {
    static func label(_ state: StrengthLiveAttributes.ContentState) -> String {
        switch state.moment {
        case .doing: String(format: C.doingLabel, state.setNumber, state.setCount)
        case .resting: C.restLabel
        case .restOver: String(format: C.restOverLabel, state.setNumber, state.setCount)
        case .paused: C.pausedLabel
        case .finished: C.finishedLabel
        }
    }

    static func color(_ moment: StrengthLiveMoment) -> Color {
        switch moment {
        case .resting: C.blue
        case .paused, .finished: C.dim
        case .doing, .restOver: C.lime
        }
    }

    static func clock(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
