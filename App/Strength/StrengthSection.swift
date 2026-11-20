import SwiftUI

struct StrengthSection: View {
    let title: String

    var body: some View {
        DSSectionTitle(title)
            .padding(.top, DSSpacing.sectionTop - StrengthConstants.detailRowSpacing)
            .padding(.bottom, DSSpacing.sectionBottom - StrengthConstants.detailRowSpacing)
    }
}
