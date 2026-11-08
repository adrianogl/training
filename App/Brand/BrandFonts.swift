import SwiftUI

enum BrandFonts {
    static func number(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold).width(.condensed).monospacedDigit()
    }
}
