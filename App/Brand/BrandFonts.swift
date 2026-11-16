import SwiftUI

enum BrandFonts {
    static let largeTitle = Font.largeTitle.weight(.heavy).width(.expanded)

    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy).width(.expanded)
    }

    static func number(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold).width(.condensed).monospacedDigit()
    }
}
