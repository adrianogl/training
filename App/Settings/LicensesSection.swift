import SwiftUI

struct LicensesSection: View {
    var body: some View {
        Section {
            Text(LicensesConstants.bodyMapLicense)
                .font(.footnote)
                .foregroundStyle(BrandColors.dim)
                .textSelection(.enabled)
        } header: {
            DSSectionTitle("\(LicensesConstants.bodyMapTitle) · \(LicensesConstants.bodyMapSource)")
        }
    }
}
