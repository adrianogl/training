import SwiftUI

struct CheckerboardView: View {
    var body: some View {
        Canvas { context, size in
            let side = ShareConstants.checkerSquare
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(BrandColors.checkerLight))
            let columns = Int((size.width / side).rounded(.up))
            let rows = Int((size.height / side).rounded(.up))
            for row in 0..<rows {
                for column in 0..<columns where (row + column).isMultiple(of: 2) {
                    let square = CGRect(x: CGFloat(column) * side, y: CGFloat(row) * side, width: side, height: side)
                    context.fill(Path(square), with: .color(BrandColors.checkerDark))
                }
            }
        }
        .accessibilityHidden(true)
    }
}
