import SwiftUI

struct RootView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var section = AppSection.initial()
    @State private var sidebarSelection: AppSection? = AppSection.initial()

    var body: some View {
        Group {
            if sizeClass == .regular {
                splitView
            } else {
                tabView
            }
        }
        .onOpenURL { url in
            guard let target = AppSection(url: url) else { return }
            section = target
            sidebarSelection = target
        }
    }

    private var tabView: some View {
        TabView(selection: $section) {
            ForEach(AppSection.allCases) { item in
                Tab(item.title, systemImage: item.systemImage, value: item) {
                    screen(for: item)
                }
            }
        }
    }

    private var splitView: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $sidebarSelection) { item in
                Label(item.title, systemImage: item.systemImage).tag(item)
            }
            .navigationTitle("trAIning")
        } detail: {
            screen(for: sidebarSelection ?? .workouts)
        }
    }

    @ViewBuilder
    private func screen(for item: AppSection) -> some View {
        switch item {
        case .workouts: WorkoutListView()
        case .settings: SettingsView()
        }
    }
}
