import SwiftUI

struct RaceChecklistCard: View {
    let items: [ChecklistItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(RacesConstants.checklistTitle).padding(.top, 0).padding(.bottom, 0)
            ForEach(items) { item in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: symbol(item.status))
                        .foregroundStyle(color(item.status))
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.subheadline.weight(.medium)).foregroundStyle(BrandColors.text)
                        Text(item.detail).font(.caption).foregroundStyle(BrandColors.dim)
                    }
                }
            }
        }
        .glassCard()
    }

    private func symbol(_ status: ChecklistStatus) -> String {
        switch status {
        case .ok: "checkmark.circle.fill"
        case .attention: "exclamationmark.circle.fill"
        case .missing: "circle.dashed"
        }
    }

    private func color(_ status: ChecklistStatus) -> Color {
        switch status {
        case .ok: BrandColors.accent
        case .attention: BrandColors.attention
        case .missing: BrandColors.dim
        }
    }
}
