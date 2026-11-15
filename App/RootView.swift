import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsIntro = !RootView.isTestHost
    @SceneStorage(NavigationRestorationConstants.sectionKey) private var sectionRaw = AppSection.today.rawValue
    @SceneStorage(NavigationRestorationConstants.sidebarKey) private var sidebarRaw = AppSection.today.rawValue
    @SceneStorage(NavigationRestorationConstants.todayPathKey) private var todayPathData = Data()
    @SceneStorage(NavigationRestorationConstants.morePathKey) private var morePathData = Data()
    @State private var appliedRestoration = false
    @State private var section = AppSection.today
    @State private var sidebarSelection: AppSection? = .today
    @State private var todayPath: [TodayRoute] = []
    @State private var morePath = NavigationPath()
    @State private var columnVisibility = NavigationSplitViewVisibility.all

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
        .onAppear(perform: applyRestoration)
        .onChange(of: section) { _, value in sectionRaw = value.rawValue }
        .onChange(of: sidebarSelection) { _, value in sidebarRaw = (value ?? .today).rawValue }
        .onChange(of: todayPath) { _, value in todayPathData = NavigationRestoration.encode(value) }
        .onChange(of: morePath) { _, value in morePathData = NavigationRestoration.encode(value) }
        .task(id: model.trainer.isLoaded) {
            guard model.trainer.isLoaded, model.trainer.plan == nil, morePath.count > 1 else { return }
            var path = morePath
            path.removeLast(path.count - 1)
            morePath = path
        }
        .task(id: model.account.token) {
            await model.garminAccount.adoptAccountSession()
        }
        .task(id: model.account.token) {
            await model.strava.refreshStatus()
        }
        .task {
            guard showsIntro else { return }
            try? await Task.sleep(for: reduceMotion ? AppConstants.introReducedMotionDuration : AppConstants.introDuration)
            withAnimation(.easeOut(duration: AppConstants.introFadeSeconds)) { showsIntro = false }
        }
        .onOpenURL { url in
            if model.strava.handles(url) {
                Task { await model.strava.refreshStatus() }
                return
            }
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

    private func applyRestoration() {
        guard !appliedRestoration else { return }
        appliedRestoration = true
        let context = ModelContext(model.container)
        section = NavigationRestoration.section(sectionRaw, allowed: AppConstants.compactTabs)
        sidebarSelection = NavigationRestoration.section(sidebarRaw, allowed: AppSection.sidebarSections)
        todayPath = NavigationRestoration.validPrefix(NavigationRestoration.decodePath(todayPathData)) { (route: TodayRoute) in
            if case .workout(let id) = route { return NavigationRestoration.hasActivity(id, in: context) }
            return true
        }
        morePath = NavigationRestoration.decodeNavigationPath(morePathData)
        if let override = AppSection.debugOverride() {
            section = override
            sidebarSelection = override
        }
        let debugPath = Self.initialTodayPath()
        if !debugPath.isEmpty { todayPath = debugPath }
        columnVisibility = Self.visibility(for: sidebarSelection ?? .today)
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
