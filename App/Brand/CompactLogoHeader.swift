import SwiftUI

struct CompactLogoHeader: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(BrandRefreshCoordinator.self) private var refresh: BrandRefreshCoordinator?

    var body: some View {
        if sizeClass != .regular {
            HStack(alignment: .center, spacing: DSSpacing.s2) {
                Logo(showsTagline: true, showsIconPlaceholder: refresh?.hidesLogo ?? false)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(BrandRefreshConstants.space)) } action: { frame in
                        refresh?.recordHeader(frame)
                    }
                Spacer(minLength: 0)
                NoticeBellButton()
            }
            .padding(.vertical, 8)
        }
    }
}
