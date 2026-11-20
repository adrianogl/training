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

    @Test func swapActionIgnoresChangesWhileSwapping() {
        #expect(RootLayout.swapAction(current: .sidebar, target: .tabs, swapping: false) == .begin)
        #expect(RootLayout.swapAction(current: .sidebar, target: .sidebar, swapping: true) == .none)
        #expect(RootLayout.swapAction(current: .tabs, target: .tabs, swapping: false) == .none)
    }

    @Test func regularCompactRegularEndsInSidebar() {
        var layout: RootLayout? = .sidebar
        var swapping = false
        var latest = RootLayout.target(sizeClass: .compact, idiom: .pad)
        #expect(RootLayout.swapAction(current: layout, target: latest, swapping: swapping) == .begin)
        swapping = true
        latest = RootLayout.target(sizeClass: .regular, idiom: .pad)
        #expect(RootLayout.swapAction(current: layout, target: latest, swapping: swapping) == .none)
        layout = latest
        swapping = false
        #expect(RootLayout.swapAction(current: layout, target: latest, swapping: swapping) == .none)
        #expect(layout == .sidebar)
    }
}
