import SwiftUI

struct RootView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var section = AppSection.initial()
    @State private var sidebarSelection: AppSection? = AppSection.initial()
    @State private var todayPath: [TodayRoute] = RootView.initialTodayPath()

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
            if target == .today {
                todayPath = url.path() == AppConstants.readinessDeepLinkPath ? [.readiness] : []
            }
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
            .safeAreaInset(edge: .bottom) { SidebarRaceCard() }
        } detail: {
            screen(for: sidebarSelection ?? .today)
        }
    }

    @ViewBuilder
    private func screen(for item: AppSection) -> some View {
        switch item {
        case .today: TodayView(path: $todayPath)
        case .evolution, .races: PlaceholderSectionView(section: item)
        case .workouts: WorkoutListView()
        case .settings: SettingsView()
        }
    }

    private static func initialTodayPath(defaults: UserDefaults = .standard) -> [TodayRoute] {
        #if DEBUG
        return defaults.string(forKey: AppConstants.openTodayDefaultsKey) == "prontidao" ? [.readiness] : []
        #else
        return []
        #endif
    }
}
