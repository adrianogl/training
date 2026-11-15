import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsIntro = !RootView.isTestHost
    @State private var section = AppSection.initial()
    @State private var sidebarSelection: AppSection? = AppSection.initial()
    @State private var todayPath: [TodayRoute] = RootView.initialTodayPath()
    @State private var morePath = NavigationPath()
    @State private var columnVisibility = RootView.visibility(for: AppSection.initial())

    var body: some View {
        Group {
            if !model.account.isSignedIn && !Self.isTestHost {
                AccountGateView(model: model.account)
            } else if sizeClass == .regular {
                splitView
            } else {
                tabView
            }
        }
        .overlay {
            if showsIntro {
                IntroView().transition(.opacity)
            }
        }
        .task(id: model.account.token) {
            await model.garminAccount.adoptAccountSession()
        }
        .task {
            guard showsIntro else { return }
            try? await Task.sleep(for: reduceMotion ? AppConstants.introReducedMotionDuration : AppConstants.introDuration)
            withAnimation(.easeOut(duration: AppConstants.introFadeSeconds)) { showsIntro = false }
        }
        .onOpenURL { url in
            guard let target = AppSection(url: url) else { return }
            open(target)
            if target == .today {
                todayPath = url.path() == AppConstants.readinessDeepLinkPath ? [.readiness] : []
            }
        }
    }

    private var tabView: some View {
        TabView(selection: $section) {
            ForEach(AppConstants.compactTabs) { item in
                Tab(item.title, systemImage: item.systemImage, value: item) {
                    screen(for: item)
                }
            }
        }
    }

    private var splitView: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(AppSection.sidebarSections, selection: $sidebarSelection) { item in
                Label(item.title, systemImage: item.systemImage).tag(item)
            }
            .navigationTitle("")
            .safeAreaInset(edge: .top) {
                Logo(showsTagline: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, BrandConstants.sidebarLogoPadding)
                    .padding(.vertical, 8)
            }
            .safeAreaInset(edge: .bottom) { SidebarRaceCard() }
        } detail: {
            screen(for: sidebarSelection ?? .today)
        }
        .onChange(of: sidebarSelection) { _, selection in
            withAnimation { columnVisibility = Self.visibility(for: selection ?? .today) }
        }
    }

    @ViewBuilder
    private func screen(for item: AppSection) -> some View {
        switch item {
        case .today: TodayView(path: $todayPath) { open(.settings) }
        case .evolution: EvolutionView()
        case .races: RaceListView()
        case .trainer: NavigationStack { TrainerView() }
        case .workouts: WorkoutListView()
        case .settings: SettingsView()
        case .more: MoreView(path: $morePath)
        }
    }

    private func open(_ target: AppSection) {
        sidebarSelection = target == .more ? .today : target
        if sizeClass != .regular && target.isInMore {
            section = .more
            var path = NavigationPath()
            path.append(target)
            morePath = path
        } else {
            section = target
        }
    }

    private static func visibility(for section: AppSection) -> NavigationSplitViewVisibility {
        AppConstants.sidebarCollapsedSections.contains(section) ? .detailOnly : .all
    }

    private static var isTestHost: Bool {
        ProcessInfo.processInfo.environment[AppConstants.testHostEnvironmentVariable] != nil
    }

    private static func initialTodayPath(defaults: UserDefaults = .standard) -> [TodayRoute] {
        #if DEBUG
        return defaults.string(forKey: AppConstants.openTodayDefaultsKey) == "prontidao" ? [.readiness] : []
        #else
        return []
        #endif
    }
}
