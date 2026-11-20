import SwiftUI
import Testing
@testable import trAIning

struct RootLayoutTests {
    @Test func iphoneUsesTabsEvenWhenRegular() {
        #expect(RootLayout.target(sizeClass: .regular, idiom: .phone) == .tabs)
        #expect(RootLayout.target(sizeClass: .compact, idiom: .phone) == .tabs)
    }

    @Test func padUsesSidebarOnlyWhenRegular() {
        #expect(RootLayout.target(sizeClass: .regular, idiom: .pad) == .sidebar)
        #expect(RootLayout.target(sizeClass: .compact, idiom: .pad) == .tabs)
        #expect(RootLayout.target(sizeClass: nil, idiom: .pad) == .tabs)
    }
}
