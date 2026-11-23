import Insights
import SwiftUI

private typealias C = StrengthLiveViewConstants
private typealias T = StrengthLiveText

struct StrengthLiveTodayCard: View {
    let snapshot: StrengthLiveSnapshot

    var body: some View {
        let card = LiveStrengthLive.card(session: snapshot.session, status: snapshot.status)
        let now = LiveStrengthLive.screen(session: snapshot.session).now
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
                }
                .brandCard()
                if let now {
                    VStack(alignment: .leading, spacing: C.cardSpacing) {
                        HStack(alignment: .top, spacing: 10) {
                            Text(now.marker).font(.footnote.bold()).foregroundStyle(BrandColors.accent).frame(width: C.markerWidth, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(now.exercise.name).font(.headline).foregroundStyle(BrandColors.text).lineLimit(1)
                                Text(T.nowSetLine(card: card, now: now)).font(.caption).foregroundStyle(BrandColors.dim)
                            }
                        }
                        StrengthLiveMomentBand(card: card)
                    }
                    .brandCard()
                }
            }
        }
        .buttonStyle(.plain)
    }
}
