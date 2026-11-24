import SwiftUI

struct DSBulletList: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.s2) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .firstTextBaseline, spacing: DSSpacing.s2) {
                    Text(DSBulletListConstants.bullet).foregroundStyle(BrandColors.dim)
                    Text(item).foregroundStyle(BrandColors.text).fixedSize(horizontal: false, vertical: true)
                }
                .font(.footnote)
            }
        }
    }
}
