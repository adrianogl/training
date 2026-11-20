import SwiftUI

enum RootLayout: Equatable {
    case tabs
    case sidebar

    static func target(sizeClass: UserInterfaceSizeClass?, idiom: UIUserInterfaceIdiom) -> RootLayout {
        sizeClass == .regular && idiom != .phone ? .sidebar : .tabs
    }

    static func swapAction(current: RootLayout?, target: RootLayout, swapping: Bool) -> RootLayoutSwapAction {
        !swapping && current != target ? .begin : .none
    }
}

enum RootLayoutSwapAction: Equatable {
    case begin
    case none
}
