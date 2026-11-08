import SwiftUI

struct WorkoutDetailPlaceholder: View {
    let row: WorkoutRowData

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(row.dateText)
                .font(.subheadline)
                .foregroundStyle(BrandColors.dim)
            Text(row.title)
                .font(.title2.bold())
                .foregroundStyle(BrandColors.text)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BrandConstants.screenPadding)
        .background(BrandBackground())
        .navigationBarTitleDisplayMode(.inline)
    }
}
