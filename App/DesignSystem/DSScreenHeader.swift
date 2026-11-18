import SwiftUI

struct DSScreenHeader<Status: View, Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var status: Status
    @ViewBuilder var trailing: Trailing

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.s2) {
            CompactLogoHeader()
            VStack(alignment: .leading, spacing: DSScreenHeaderConstants.statusSpacing) {
                status
            }
            VStack(alignment: .leading, spacing: 2) {
                if let subtitle {
                    Text(subtitle).font(.footnote).foregroundStyle(BrandColors.dim)
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(BrandFonts.largeTitle)
                        .foregroundStyle(BrandColors.text)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: DSSpacing.s2)
                    trailing
                }
            }
        }
        .padding(.bottom, DSScreenHeaderConstants.bottomSpacing)
    }
}

extension DSScreenHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, @ViewBuilder status: () -> Status) {
        self.init(title: title, subtitle: subtitle, status: status, trailing: { EmptyView() })
    }
}

extension DSScreenHeader where Status == EmptyView, Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle, status: { EmptyView() }, trailing: { EmptyView() })
    }
}

struct DSAddButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.title3.weight(.semibold))
                .foregroundStyle(BrandColors.onAccent)
                .frame(width: DSScreenHeaderConstants.addSize, height: DSScreenHeaderConstants.addSize)
                .background(BrandColors.accentFill, in: Circle())
        }
        .buttonStyle(.cardLink)
        .accessibilityLabel(label)
    }
}
