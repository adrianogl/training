import SwiftUI

struct FirstSyncView: View {
    var body: some View {
        VStack(spacing: FirstSyncConstants.spacing) {
            BrandLoader(size: .large)
                .padding(BrandLoaderConstants.large.ringGap)
            Text(FirstSyncConstants.title)
                .font(.headline)
                .foregroundStyle(BrandColors.text)
                .multilineTextAlignment(.center)
            Text(FirstSyncConstants.detail)
                .font(.footnote)
                .foregroundStyle(BrandColors.dim)
                .multilineTextAlignment(.center)
                .frame(maxWidth: FirstSyncConstants.detailMaxWidth)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FirstSyncConstants.verticalPadding)
        .accessibilityElement(children: .combine)
    }
}
