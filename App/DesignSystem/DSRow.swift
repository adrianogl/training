import SwiftUI

enum DSRowAccessory {
    case none, link, disclosure(expanded: Bool)
}

struct DSRow<Trailing: View>: View {
    let title: String
    var subtitle: String?
    var accessory: DSRowAccessory = .none
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center, spacing: DSSpacing.s3) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(BrandColors.text)
                if let subtitle {
                    Text(subtitle).font(.caption).foregroundStyle(BrandColors.dim)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: DSSpacing.s2)
            trailing
            switch accessory {
            case .none: EmptyView()
            case .link: CardLinkBadge()
            case .disclosure(let expanded): CardDisclosure(expanded: expanded)
            }
        }
        .contentShape(Rectangle())
    }
}

extension DSRow where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, accessory: DSRowAccessory = .none) {
        self.init(title: title, subtitle: subtitle, accessory: accessory) { EmptyView() }
    }
}
