import ActivityKit
import SwiftUI
import WidgetKit

private typealias C = StrengthLiveWidgetConstants

struct StrengthLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StrengthLiveAttributes.self) { context in
            StrengthLiveLockView(title: context.attributes.title, state: context.state)
                .activityBackgroundTint(C.background)
                .activitySystemActionForegroundColor(C.text)
                .widgetURL(C.deepLink)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(StrengthLiveText.label(state)).font(.caption.bold()).foregroundStyle(StrengthLiveText.color(state.moment)).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(state.setsDone)/\(state.setsTotal)").font(.caption.monospacedDigit().bold()).foregroundStyle(C.lilac)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .bottom) {
                            StrengthLiveDetail(state: state)
                            Spacer(minLength: 0)
                            StrengthLiveBig(state: state)
                        }
                        StrengthLiveBar(state: state)
                    }
                    .foregroundStyle(C.text)
                }
            } compactLeading: {
                HStack(spacing: 6) {
                    Circle().fill(StrengthLiveText.color(state.moment)).frame(width: 8, height: 8)
                    Text(StrengthLiveIsland.leading(state)).font(.caption.bold()).foregroundStyle(StrengthLiveText.color(state.moment)).lineLimit(1)
                }
            } compactTrailing: {
                StrengthLiveIsland.trailing(state)
            } minimal: {
                Circle().fill(StrengthLiveText.color(state.moment)).frame(width: 10, height: 10)
            }
            .widgetURL(C.deepLink)
            .keylineTint(StrengthLiveText.color(state.moment))
        }
    }
}

enum StrengthLiveIsland {
    static func leading(_ state: StrengthLiveAttributes.ContentState) -> String {
        switch state.moment {
        case .resting: C.islandRest
        case .restOver: String(format: C.islandRestOver, state.setNumber)
        case .paused: C.islandPaused
        case .finished: StrengthLiveText.label(state)
        case .doing: "\(state.shortName ?? "") \(state.setNumber)/\(state.setCount)"
        }
    }

    @ViewBuilder static func trailing(_ state: StrengthLiveAttributes.ContentState) -> some View {
        switch state.moment {
        case .resting:
            if let ends = state.restEndsAt {
                Text(timerInterval: Date.now...max(ends, .now), countsDown: true)
                    .font(.callout.monospacedDigit().bold()).foregroundStyle(C.blue).frame(maxWidth: 48)
            }
        case .restOver:
            if let ends = state.restEndsAt {
                (Text(C.plus) + Text(timerInterval: ends...Date.distantFuture, countsDown: false))
                    .font(.callout.monospacedDigit().bold()).foregroundStyle(C.yellow).frame(maxWidth: 56)
            }
        default:
            Text(state.target ?? "").font(.callout.monospacedDigit().bold()).foregroundStyle(C.lime)
        }
    }
}
