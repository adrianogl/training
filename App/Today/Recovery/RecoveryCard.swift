import SwiftUI

struct RecoveryCard: View {
    let estimate: RecoveryEstimate
    let now: Date

    private typealias C = RecoveryConstants

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(C.title).padding(.top, 0).padding(.bottom, 0)
            GeometryReader { proxy in
                Capsule().fill(BrandColors.track)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(estimate.progress >= 1 ? BrandColors.accentFill : BrandColors.attention)
                            .frame(width: proxy.size.width * estimate.progress)
                    }
            }
            .frame(height: 10)
            HStack {
                Text(String(format: C.sinceFormat, estimate.title)).font(.caption).foregroundStyle(BrandColors.dim).lineLimit(1)
                Spacer()
                Text(status).font(BrandFonts.number(15)).foregroundStyle(BrandColors.text)
            }
            if let next = estimate.next {
                HStack {
                    Text(next.title).font(.subheadline).foregroundStyle(BrandColors.text).lineLimit(1)
                    Spacer()
                    Text(String(format: C.afterFormat, next.gapHours)).font(BrandFonts.number(14)).foregroundStyle(BrandColors.dim)
                    Text(next.enough ? C.enough : C.short)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(next.enough ? BrandColors.accent : BrandColors.attention)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background((next.enough ? BrandColors.accentFill : BrandColors.attention).opacity(0.15), in: Capsule())
                }
                Text(next.enough
                    ? String(format: C.enoughNoteFormat, next.title, next.gapHours)
                    : String(format: C.shortNoteFormat, next.title, next.gapHours, estimate.hours))
                    .font(.caption).foregroundStyle(BrandColors.dim).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .brandCard()
    }

    private var status: String {
        let remaining = Int((estimate.readyAt.timeIntervalSince(now) / 3_600).rounded())
        guard remaining > 0 else { return C.readyNow }
        let day = estimate.readyAt.formatted(.dateTime.weekday(.abbreviated).locale(WorkoutConstants.locale))
        let when = String(format: C.whenFormat, day, Calendar.current.component(.hour, from: estimate.readyAt))
        return String(format: C.readyFormat, remaining, when)
    }
}
