import SwiftUI

struct StrengthCardHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title).font(.caption.weight(.semibold)).tracking(1).textCase(.uppercase).foregroundStyle(BrandColors.dim)
            Spacer()
        }
    }
}
