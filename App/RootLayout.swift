import SwiftUI

enum RootLayout: Equatable {
    case tabs
    case sidebar

    static func target(sizeClass: UserInterfaceSizeClass?, idiom: UIUserInterfaceIdiom) -> RootLayout {
        sizeClass == .regular && idiom != .phone ? .sidebar : .tabs
    }
}
