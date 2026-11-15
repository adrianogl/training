import SwiftUI

struct CompactLogoHeader: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(BrandRefreshCoordinator.self) private var refresh: BrandRefreshCoordinator?

    var body: some View {
        if sizeClass != .regular {
            Logo(showsTagline: true, showsIconPlaceholder: refresh?.hidesLogo ?? false)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(BrandRefreshConstants.space)) } action: { frame in
                    refresh?.recordHeader(frame)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
        }
    }
}
