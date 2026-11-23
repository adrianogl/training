import Insights
import SwiftUI

private typealias C = StrengthLiveViewConstants
private typealias T = StrengthLiveText

struct StrengthLiveTodayCard: View {
    let snapshot: StrengthLiveSnapshot

    var body: some View {
        let card = LiveStrengthLive.card(session: snapshot.session, status: snapshot.status)
        Button {
            if let url = URL(string: DeepLinkConstants.trainerStrength) { _ = DeepLinkCenter.shared.open(url) }
        } label: {
            VStack(alignment: .leading, spacing: DSSpacing.s2) {
                HStack {
                    DSSectionTitle(T.todayTitle)
                    CardLinkChevron()
                }
                VStack(alignment: .leading, spacing: C.cardSpacing) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(snapshot.session.plan.title).font(.headline.weight(.bold)).foregroundStyle(BrandColors.text)
                        Spacer()
                        DSChip(text: T.onWatch, tone: .strength)
                    }
                    StrengthLiveStatsContent(startedAt: snapshot.startedAt, card: card)
                    Rectangle().fill(BrandColors.line).frame(height: 1)
                    moment(card)
                }
                .brandCard()
            }
        }
        .buttonStyle(.plain)
    }

    private func moment(_ card: LiveStrengthCard) -> some View {
        let color = card.moment == .resting ? BrandColors.fitness : card.moment == .paused ? BrandColors.dim : BrandColors.accent
        return HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(T.momentLabel(card)).font(.caption.weight(.bold)).textCase(.uppercase).foregroundStyle(color)
                if let line = T.todayLine(card) {
                    Text(line).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Group {
                if card.moment == .resting, let ends = card.restEndsAt {
                    Text(timerInterval: Date.now...max(ends, .now), countsDown: true).foregroundStyle(BrandColors.fitness)
                } else if card.moment == .restOver, let ends = card.restEndsAt {
                    (Text("+") + Text(timerInterval: ends...Date.distantFuture, countsDown: false)).foregroundStyle(BrandColors.attention)
                } else if let target = card.target {
                    Text(target).foregroundStyle(color)
                }
            }
            .font(.system(size: C.restSize, weight: .heavy, design: .rounded).monospacedDigit())
            .multilineTextAlignment(.trailing)
            .fixedSize()
        }
    }
}
