import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @SceneStorage(NavigationRestorationConstants.sectionKey) private var sectionRaw = AppSection.today.rawValue
    @SceneStorage(NavigationRestorationConstants.sidebarKey) private var sidebarRaw = AppSection.today.rawValue
    @SceneStorage(NavigationRestorationConstants.todayPathKey) private var todayPathData = Data()
    @State private var appliedRestoration = false
    @State private var section = AppSection.today
    @State private var sidebarSelection: AppSection? = .today
    @State private var todayPath: [TodayRoute] = []
    @State private var trainerPath: [TrainerRoute] = []
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var layout: RootLayout?
    @State private var swappingLayout = false
    @State private var latestSizeClass: UserInterfaceSizeClass?
    @State private var showsTrainerSend = false

    var body: some View {
        Group {
            if usesSidebar {
                splitView
            } else {
                tabView
            }
        }
        .environment(\.planZones, model.trainer.planZones)
        .onAppear {
            latestSizeClass = sizeClass
            layout = layout ?? targetLayout
            applyRestoration()
        }
        .fullScreenCover(isPresented: Binding(get: { model.watchKind == nil }, set: { _ in })) {
            WatchChoiceView { model.chooseWatch($0) }
        }
        .onChange(of: sizeClass) { _, value in
            latestSizeClass = value
            beginLayoutSwap()
        }
        .onChange(of: section) { _, value in sectionRaw = value.rawValue }
        .onChange(of: sidebarSelection) { _, value in sidebarRaw = (value ?? .today).rawValue }
        .onChange(of: todayPath) { _, value in todayPathData = NavigationRestoration.encode(value) }
        .task(id: model.account.token) {
            await model.garminAccount.adoptAccountSession()
        }
        .task(id: model.account.token) {
            await model.strava.refreshStatus()
        }
        .onOpenURL { url in
            if WatchLink.shared.handles(url) { return }
            if model.strava.handles(url) {
                Task { await model.strava.refreshStatus() }
                return
            }
            DeepLinkCenter.shared.open(url)
        }
        .onChange(of: DeepLinkCenter.shared.pending, initial: true) { _, _ in follow() }
        .sheet(isPresented: $showsTrainerSend) { TrainerSendSheet() }
    }

    private var targetLayout: RootLayout {
        RootLayout.target(sizeClass: latestSizeClass ?? sizeClass, idiom: UIDevice.current.userInterfaceIdiom)
    }

    private var usesSidebar: Bool {
        (layout ?? targetLayout) == .sidebar
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
                HStack(alignment: .center, spacing: DSSpacing.s2) {
                    Logo(showsTagline: true)
                    Spacer(minLength: 0)
                    NoticeBellButton()
                }
                .padding(.horizontal, BrandConstants.sidebarLogoPadding)
                .padding(.vertical, 8)
            }
            .safeAreaInset(edge: .bottom) { SidebarRaceCard() }
        } detail: {
            HStack(spacing: 0) { screen(for: sidebarSelection ?? .today) }
        }
    }

    @ViewBuilder
    private func screen(for item: AppSection) -> some View {
        switch item {
        case .today: TodayView(path: $todayPath) { open(.settings) }
        case .evolution: EvolutionView()
        case .races: RaceListView()
        case .trainer: NavigationStack(path: $trainerPath) { TrainerView() }
        case .workouts: WorkoutsHubView(trainerPath: $trainerPath)
        case .settings: SettingsView()
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
            if case .planned = route { return false }
            return true
        }
        if let override = AppSection.debugOverride() {
            section = override
            sidebarSelection = override
        }
        let debugPath = Self.initialTodayPath()
        if !debugPath.isEmpty { todayPath = debugPath }
    }

    private func beginLayoutSwap() {
        guard RootLayout.swapAction(current: layout, target: targetLayout, swapping: swappingLayout) == .begin else { return }
        swappingLayout = true
        todayPath = []
        trainerPath = []
        Task { @MainActor in
            layout = targetLayout
            swappingLayout = false
            beginLayoutSwap()
            follow()
        }
    }

    private func follow() {
        guard !swappingLayout else { return }
        applyRestoration()
        guard let link = DeepLinkCenter.shared.pending else { return }
        if link == .trainerSend {
            showsTrainerSend = true
            _ = DeepLinkCenter.shared.take()
            return
        }
        open(link.section)
        switch link {
        case .readiness:
            todayPath = [.readiness]
        case .section(.today):
            todayPath = []
        case .trainer(let route):
            UserDefaults.standard.set(WorkoutListMode.week.rawValue, forKey: WorkoutCalendarConstants.modeKey)
            trainerPath = [route]
        case .workout, .section, .trainerSend:
            break
        }
        if case .workout = link { return }
        _ = DeepLinkCenter.shared.take()
    }

    private func open(_ target: AppSection) {
        sidebarSelection = target
        section = target
    }

    private static func initialTodayPath(defaults: UserDefaults = .standard) -> [TodayRoute] {
        #if DEBUG
        return defaults.string(forKey: AppConstants.openTodayDefaultsKey) == "prontidao" ? [.readiness] : []
        #else
        return []
        #endif
    }
}
