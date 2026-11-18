import SwiftUI
import UserNotifications

@main
struct TrainingApp: App {
    @State private var session: AppSession
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppConstants.appearanceDefaultsKey) private var appearance = AppearanceOption.system.rawValue
    @AppStorage(AccentThemeConstants.defaultsKey) private var accentTheme = AccentTheme.pista.rawValue

    init() {
        let reference = AppSessionReference()
        BackgroundSync.register { reference.session?.model }
        UNUserNotificationCenter.current().delegate = NotificationRouter.shared
        let session = AppSession.live()
        reference.session = session
        _session = State(initialValue: session)
    }

    var body: some Scene {
        WindowGroup {
            SessionRootView(session: session)
                .preferredColorScheme(AppearanceOption(rawValue: appearance)?.colorScheme)
                .environment(\.accentTheme, AccentTheme.stored(accentTheme))
                .tint(BrandColors.accent)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .active:
                session.model?.activate()
            case .background:
                session.model?.enteredBackground()
            default:
                break
            }
        }
    }
}
