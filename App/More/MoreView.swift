import SwiftUI

struct MoreView: View {
    @Binding var path: NavigationPath

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    CompactLogoHeader()
                    Text(AppSection.more.title)
                        .font(BrandFonts.largeTitle)
                        .foregroundStyle(BrandColors.text)
                        .padding(.bottom, 14)
                    VStack(spacing: 0) {
                        ForEach(Array(AppConstants.moreItems.enumerated()), id: \.element) { index, item in
                            if index > 0 { Divider().overlay(BrandColors.line).padding(.leading, MoreConstants.dividerInset) }
                            NavigationLink(value: item) { row(item) }
                                .buttonStyle(.plain)
                        }
                    }
                    .brandCard()
                }
                .padding(.horizontal, BrandConstants.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(BrandBackground())
            .toolbarVisibility(.hidden, for: .navigationBar)
            .navigationDestination(for: AppSection.self) { item in
                switch item {
                case .races: RaceListView(embedded: true)
                case .trainer: TrainerView()
                case .settings: SettingsView(embedded: true)
                default: EmptyView()
                }
            }
        }
    }

    private func row(_ item: AppSection) -> some View {
        HStack(spacing: 14) {
            Image(systemName: item.systemImage)
                .font(.title3)
                .foregroundStyle(BrandColors.accent)
                .frame(width: MoreConstants.iconWidth)
            Text(item.title).font(.body).foregroundStyle(BrandColors.text)
            Spacer()
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(BrandColors.dim)
        }
        .padding(.vertical, MoreConstants.rowPadding)
        .contentShape(Rectangle())
    }
}
