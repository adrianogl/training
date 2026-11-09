import SwiftUI

struct PlaceholderSectionView: View {
    let section: AppSection

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: section.systemImage)
                .font(.largeTitle)
                .foregroundStyle(BrandColors.accent)
            Text(section.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(BrandColors.text)
            Text(TodayConstants.comingSoon)
                .foregroundStyle(BrandColors.dim)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BrandBackground())
    }
}
